import { test, expect, FIXTURES } from "./fixtures";

test.describe("Recompression Tests", () => {
  test("should recompress when changing JPEG quality", async ({
    page,
    waitForWasm,
    uploadAndWaitForCompression,
  }) => {
    await page.goto("/");
    await waitForWasm();
    await uploadAndWaitForCompression(FIXTURES.JPEG);

    const initialSize = await page
      .getByTestId("total-compressed-size")
      .textContent();

    const qualitySlider = page.getByTestId("quality-slider");
    await qualitySlider.fill("70");
    await page.waitForTimeout(1000);

    const newSize = await page
      .getByTestId("total-compressed-size")
      .textContent();
    expect(newSize).not.toBe(initialSize);
    await expect(page.getByTestId("compressed-image-overlay")).toBeVisible();
  });

  test("should recompress when toggling lossless", async ({
    page,
    waitForWasm,
    uploadAndWaitForCompression,
  }) => {
    await page.goto("/");
    await waitForWasm();
    await uploadAndWaitForCompression(FIXTURES.PNG);

    const initialSize = await page
      .getByTestId("total-compressed-size")
      .textContent();

    await page.getByRole("checkbox", { name: "Lossless" }).click();
    await page.waitForTimeout(1000);

    const newSize = await page
      .getByTestId("total-compressed-size")
      .textContent();
    expect(newSize).not.toBe(initialSize);
    await expect(page.getByTestId("compressed-image-overlay")).toBeVisible();
  });
});
