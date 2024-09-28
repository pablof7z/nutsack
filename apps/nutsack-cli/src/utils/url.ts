export function normalizeRelayUrl(url: string): string {
  if (!url.startsWith('ws://') && !url.startsWith('wss://')) {
    if (url.startsWith('localhost') || url.startsWith('127.0.0.1')) {
      return `ws://${url}`;
    }
    return `wss://${url}`;
  }
  return url;
}
