/// 后台线程把压缩 JSON 格式化成可读文本,避免主线程在
/// `JSON.stringify(JSON.parse(content), null, 2)` 上阻塞 UI。
self.addEventListener("message", (event: MessageEvent<string>) => {
  const raw = event.data;
  try {
    const pretty = JSON.stringify(JSON.parse(raw), null, 2);
    (self as unknown as Worker).postMessage({ ok: true, pretty });
  } catch (error) {
    (self as unknown as Worker).postMessage({
      ok: false,
      error: error instanceof Error ? error.message : String(error),
    });
  }
});
