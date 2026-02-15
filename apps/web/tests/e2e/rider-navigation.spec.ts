import { expect, test, type Page } from "@playwright/test";

async function settlePage(page: Page) {
  await page.waitForLoadState("domcontentloaded");
  await page.waitForTimeout(600);
}

test.describe("Rider navigation maps", () => {
  test("navigation lab renders all map modules", async ({ page }) => {
    await page.goto("/en/rider/navigation-lab");
    await settlePage(page);

    await expect(page.getByTestId("rider-navigation-lab")).toBeVisible();
    await expect(page.getByTestId("ping-beacon-map")).toBeVisible();
    await expect(page.getByTestId("trip-route-map")).toBeVisible();
    await expect(page.getByTestId("multi-stop-route-map")).toBeVisible();
    await expect(page.getByTestId("order-tracking-map")).toBeVisible();
    await expect(page.locator(".leaflet-container")).toHaveCount(4);
  });

  test("navigation lab visual snapshot", async ({ page }) => {
    await page.goto("/en/rider/navigation-lab");
    await settlePage(page);

    await expect(page).toHaveScreenshot("rider-navigation-lab.png", {
      fullPage: true,
      // Mask tile layers so map-provider tiles do not introduce visual flake.
      mask: [page.locator(".leaflet-tile-container"), page.locator("time")],
    });
  });
});
