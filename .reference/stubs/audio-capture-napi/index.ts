// Stub: audio-capture-napi — native CoreAudio module (not available without Swift/Rust binaries)
export function isNativeAudioAvailable(): boolean { return false; }
export function startRecording(_opts: any): void { throw new Error('[STUB] audio-capture-napi not available'); }
export function stopRecording(): Promise<Buffer> { throw new Error('[STUB] audio-capture-napi not available'); }
export function isRecording(): boolean { return false; }
