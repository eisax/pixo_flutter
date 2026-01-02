import { compressImage, resizeImage } from "./wasm";
import type { CompressOptions } from "./wasm";

interface CompressMessage {
  id: string;
  type: "compress";
  width: number;
  height: number;
  data: ArrayBuffer;
  options: CompressOptions;
}

interface ResizeMessage {
  id: string;
  type: "resize";
  width: number;
  height: number;
  data: ArrayBuffer;
  options: {
    width: number;
    height: number;
    algorithm: "nearest" | "bilinear" | "lanczos3";
    maintainAspectRatio: boolean;
  };
}

interface CancelMessage {
  id: string;
  type: "cancel";
}

type WorkerMessage = CompressMessage | ResizeMessage | CancelMessage;

const cancelledTasks = new Set<string>();

self.onmessage = async (e: MessageEvent<WorkerMessage>) => {
  const { id, type } = e.data;

  if (type === "cancel") {
    cancelledTasks.add(id);
    return;
  }

  try {
    if (type === "compress") {
      const { width, height, data, options } = e.data;
      const imageData = new ImageData(
        new Uint8ClampedArray(data),
        width,
        height,
      );
      const result = await compressImage(imageData, options);

      if (cancelledTasks.has(id)) {
        cancelledTasks.delete(id);
        return;
      }

      self.postMessage({
        id,
        success: true,
        result: {
          blob: result.blob,
          elapsedMs: result.elapsedMs,
        },
      });
    } else if (type === "resize") {
      const { width, height, data, options } = e.data;
      const imageData = new ImageData(
        new Uint8ClampedArray(data),
        width,
        height,
      );
      const result = await resizeImage(imageData, options);

      if (cancelledTasks.has(id)) {
        cancelledTasks.delete(id);
        return;
      }

      const resultBuffer = result.data.buffer;
      self.postMessage(
        {
          id,
          success: true,
          result: {
            width: result.width,
            height: result.height,
            data: resultBuffer,
          },
        },
        { transfer: [resultBuffer] },
      );
    }
  } catch (error) {
    if (cancelledTasks.has(id)) {
      cancelledTasks.delete(id);
      return;
    }

    const errorMessage =
      error instanceof Error ? error.message : "Unknown error";
    const errorType =
      errorMessage.includes("WASM") || errorMessage.includes("module")
        ? "wasm_init"
        : errorMessage.includes("memory") || errorMessage.includes("allocation")
          ? "out_of_memory"
          : "unknown";

    self.postMessage({
      id,
      success: false,
      error: errorMessage,
      errorType,
    });
  }
};
