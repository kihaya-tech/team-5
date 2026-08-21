// ブラウザ内でffmpeg.wasmを使い、撮影動画を720p縦型mp4に変換する。
// ステッカーはCanvasで絵文字をPNGに描画し、overlayフィルタで焼き付ける。
// Flutter(Dart)側からwindow.processVideoWeb(bytes, stickersJson)で呼び出す。

let _ffmpeg = null;
let _loadPromise = null;

function _log(...args) {
  console.log('%c[ffmpeg-web]', 'color:#7c4dff;font-weight:bold', ...args);
}
function _err(...args) {
  console.error('%c[ffmpeg-web]', 'color:#ff5252;font-weight:bold', ...args);
}

// ファイルを取得しblob URL化する。404やHTMLフォールバックを掴んでいないか検証する。
async function _toBlobURL(url, mimeType) {
  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`取得失敗 HTTP ${res.status} ${res.statusText}: ${url}`);
  }
  const ct = res.headers.get('content-type') || '(none)';
  const buf = await res.arrayBuffer();
  const head = new TextDecoder()
    .decode(new Uint8Array(buf.slice(0, 64)))
    .trimStart();
  if (head.startsWith('<!DOCTYPE') || head.startsWith('<html')) {
    throw new Error(
      `JSの代わりにHTMLが返却された（パス誤り/404フォールバックの疑い）: ${url}`,
    );
  }
  _log(`fetched ${url} -> ${res.status} / ${ct} / ${buf.byteLength}B`);
  return URL.createObjectURL(new Blob([buf], { type: mimeType }));
}

// ffmpeg.wasm本体を一度だけ読み込む（初回のみ約31MBのコアをダウンロード）。
async function _ensureLoaded() {
  if (_ffmpeg) {
    _log('既にロード済み（キャッシュ利用）');
    return _ffmpeg;
  }
  if (_loadPromise) {
    _log('ロード中の処理を待機');
    return _loadPromise;
  }

  _loadPromise = (async () => {
    const t0 = performance.now();
    try {
      _log('ロード開始');
      if (typeof FFmpegWASM === 'undefined') {
        throw new Error('FFmpegWASM が未定義（/ffmpeg/ffmpeg.js が読み込めていない）');
      }
      const { FFmpeg } = FFmpegWASM;
      const ffmpeg = new FFmpeg();

      ffmpeg.on('log', ({ type, message }) => _log(`(${type})`, message));
      ffmpeg.on('progress', ({ progress, time }) => {
        _log(`進捗 ${(progress * 100).toFixed(1)}%  time=${time}`);
      });

      const base = '/ffmpeg';
      _log('blob化開始', base);
      const coreURL = await _toBlobURL(`${base}/ffmpeg-core.js`, 'text/javascript');
      const wasmURL = await _toBlobURL(`${base}/ffmpeg-core.wasm`, 'application/wasm');
      _log('blob化完了');

      // classWorkerURL はマルチスレッド版でのみ必要。
      // シングルスレッド版では渡すと "failed to import ffmpeg-core.js" が発生する。
      _log('ffmpeg.load() 実行');
      await ffmpeg.load({ coreURL, wasmURL });

      _ffmpeg = ffmpeg;
      _log(`ロード完了 (${(performance.now() - t0).toFixed(0)}ms)`);
      return ffmpeg;
    } catch (e) {
      _err('ロード失敗:', e);
      _loadPromise = null;
      throw e;
    }
  })();

  return _loadPromise;
}

// 絵文字を size×size のPNG(Uint8Array)にレンダリングする。
async function _renderEmojiToPng(emoji, size) {
  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext('2d');
  ctx.font = `${Math.floor(size * 0.75)}px serif`;
  ctx.textBaseline = 'middle';
  ctx.textAlign = 'center';
  ctx.fillText(emoji, size / 2, size / 2);
  return new Promise((resolve) => {
    canvas.toBlob((blob) => {
      blob.arrayBuffer().then((buf) => resolve(new Uint8Array(buf)));
    }, 'image/png');
  });
}

// 入力動画のバイト列とステッカーJSONを受け取り、720x1280縦型mp4のバイト列を返す。
// stickersJson: [{emoji, col, row}] の配列。col/rowはffmpegのoverlay座標(ピクセル)。
async function processVideoWeb(inputBytes, stickersJson) {
  const t0 = performance.now();
  const stickers = JSON.parse(stickersJson || '[]');
  _log(`変換開始: 入力 ${inputBytes.length} bytes, ステッカー ${stickers.length} 件`);

  try {
    const ffmpeg = await _ensureLoaded();
    const inputName = 'input.webm';
    const outputName = 'output.mp4';

    await ffmpeg.writeFile(inputName, inputBytes);

    // ステッカーをPNGに変換してffmpegの仮想FSに書き込む
    const stickerEntries = [];
    for (let i = 0; i < stickers.length; i++) {
      const { emoji, col, row } = stickers[i];
      const png = await _renderEmojiToPng(emoji, 80);
      const name = `sticker_${i}.png`;
      await ffmpeg.writeFile(name, png);
      stickerEntries.push({ name, col, row });
      _log(`ステッカー${i}: emoji=${emoji} col=${col} row=${row}`);
    }

    // 黒帯を出さず720x1280の縦枠いっぱいに収める（cover）。
    // 枠に合わない分は中央基準で切り落とす。カメラプレビューのBoxFit.coverと同じ見え方。
    const resize =
      'scale=720:1280:force_original_aspect_ratio=increase,' +
      'crop=720:1280';

    // コマンド引数を配列で組み立てる（特殊文字を安全に扱うため）
    const args = ['-y', '-i', inputName];
    for (const { name } of stickerEntries) {
      args.push('-i', name);
    }

    if (stickerEntries.length === 0) {
      args.push('-vf', resize);
    } else {
      // filter_complex: リサイズ後に各ステッカーを順番にoverlay
      let filter = `[0:v]${resize}[base];`;
      for (let i = 0; i < stickerEntries.length; i++) {
        const { col, row } = stickerEntries[i];
        const src = i === 0 ? '[base]' : `[v${i}]`;
        const dst = i === stickerEntries.length - 1 ? '[out]' : `[v${i + 1}]`;
        filter += `${src}[${i + 1}:v]overlay=${col}:${row}${dst}`;
        if (i < stickerEntries.length - 1) filter += ';';
      }
      args.push('-filter_complex', filter, '-map', '[out]', '-map', '0:a?');
    }

    args.push(
      '-c:v', 'libx264', '-preset', 'fast', '-crf', '23',
      '-c:a', 'aac', '-b:a', '128k',
      '-movflags', '+faststart',
      outputName,
    );

    _log('exec:', args.join(' '));
    const tExec = performance.now();
    await ffmpeg.exec(args);
    _log(`exec完了 (${(performance.now() - tExec).toFixed(0)}ms)`);

    const data = await ffmpeg.readFile(outputName);
    _log(`変換完了: 出力 ${data.length} bytes (${(data.length / 1024 / 1024).toFixed(2)} MB)`);

    // 仮想FS上の一時ファイルを削除
    try { await ffmpeg.deleteFile(inputName); } catch (e) {}
    try { await ffmpeg.deleteFile(outputName); } catch (e) {}
    for (const { name } of stickerEntries) {
      try { await ffmpeg.deleteFile(name); } catch (e) {}
    }

    _log(`総処理時間 ${(performance.now() - t0).toFixed(0)}ms`);
    return data;
  } catch (e) {
    _err('変換失敗:', e);
    throw e;
  }
}

// AIアバター/シチュエーション動画（2秒のWebM動画）をブラウザのCanvasから完全無料で生成する
async function generateAIVideoWeb(title, emoji, bgGradientStart, bgGradientEnd) {
  _log(`AI動画生成開始: ${title} (${emoji})`);
  const canvas = document.createElement('canvas');
  canvas.width = 720;
  canvas.height = 1280;
  const ctx = canvas.getContext('2d');

  const stream = canvas.captureStream(30);
  let mimeType = 'video/webm;codecs=vp8';
  if (!MediaRecorder.isTypeSupported(mimeType)) {
    mimeType = 'video/webm';
  }
  const recorder = new MediaRecorder(stream, { mimeType, videoBitsPerSecond: 2500000 });
  const chunks = [];
  recorder.ondataavailable = (e) => {
    if (e.data && e.data.size > 0) chunks.push(e.data);
  };

  const recordingFinished = new Promise((resolve) => {
    recorder.onstop = () => resolve(new Blob(chunks, { type: mimeType }));
  });

  recorder.start();
  const startTime = performance.now();
  const durationMs = 2000;

  await new Promise((resolve) => {
    function drawFrame(currentTime) {
      const elapsed = currentTime - startTime;
      const progress = Math.min(elapsed / durationMs, 1.0);

      // 背景グラデーション
      const grad = ctx.createLinearGradient(0, 0, 720, 1280);
      grad.addColorStop(0, bgGradientStart);
      grad.addColorStop(1, bgGradientEnd);
      ctx.fillStyle = grad;
      ctx.fillRect(0, 0, 720, 1280);

      // 背景の動的な装飾（光の輪）
      const pulse = Math.sin(progress * Math.PI * 4) * 20;
      ctx.save();
      ctx.beginPath();
      ctx.arc(360, 600, 220 + pulse, 0, Math.PI * 2);
      ctx.fillStyle = 'rgba(255, 255, 255, 0.15)';
      ctx.fill();
      ctx.restore();

      // 「AI LOG」バッジ
      ctx.save();
      ctx.fillStyle = 'rgba(0, 0, 0, 0.3)';
      ctx.roundRect ? ctx.roundRect(240, 240, 240, 60, 30) : ctx.rect(240, 240, 240, 60);
      ctx.fill();
      ctx.font = 'bold 28px sans-serif';
      ctx.fillStyle = '#2ECDB0';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText('✨ AI LOG', 360, 270);
      ctx.restore();

      // メイン絵文字（ぷるぷる揺れるアニメーション）
      const bounce = Math.sin(progress * Math.PI * 6) * 25;
      const angle = Math.sin(progress * Math.PI * 4) * 0.1;
      ctx.save();
      ctx.translate(360, 580 + bounce);
      ctx.rotate(angle);
      ctx.font = '160px serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(emoji, 0, 0);
      ctx.restore();

      // タイトルテキスト
      ctx.save();
      ctx.font = 'bold 44px sans-serif';
      ctx.fillStyle = '#FFFFFF';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.shadowColor = 'rgba(0, 0, 0, 0.5)';
      ctx.shadowBlur = 12;
      ctx.fillText(title, 360, 820);

      ctx.font = '30px sans-serif';
      ctx.fillStyle = 'rgba(255, 255, 255, 0.85)';
      ctx.fillText('自動生成された日常ログ', 360, 880);
      ctx.restore();

      if (progress < 1.0) {
        requestAnimationFrame(drawFrame);
      } else {
        recorder.stop();
        resolve();
      }
    }
    requestAnimationFrame(drawFrame);
  });

  const blob = await recordingFinished;
  const arrayBuffer = await blob.arrayBuffer();
  _log(`AI動画生成完了: ${arrayBuffer.byteLength} bytes`);
  return URL.createObjectURL(blob);
}

window.processVideoWeb = processVideoWeb;
window.generateAIVideoWeb = generateAIVideoWeb;

