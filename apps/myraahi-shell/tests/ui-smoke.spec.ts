import { test, expect, type Page } from "@playwright/test";

const locations = [
  { id: "loc-gomoh", slug: "gomoh", display_name: "Gomoh", region: "Dhanbad district", state: "LIVE" },
  { id: "loc-dhanbad", slug: "dhanbad", display_name: "Dhanbad", region: "Dhanbad district", state: "LIVE" },
];

const gomohCatalog = {
  location: { slug: "gomoh", display_name: "Gomoh", region: "Dhanbad district", state: "LIVE" },
  products: [
    {
      key: "learning",
      display_name: "Learning",
      short_description: "Find teachers and learning opportunities near you.",
      icon_ref: "learning",
      state: "LIVE",
      entry_url: "https://learning.myraahi.co.in/",
      availability_message: null,
    },
    {
      key: "toto",
      display_name: "ToTo",
      short_description: "Find local transport options for your journey.",
      icon_ref: "toto",
      state: "LIVE",
      entry_url: "https://myraahi.co.in/toto",
      availability_message: null,
    },
  ],
};

const dhanbadCatalog = {
  location: { slug: "dhanbad", display_name: "Dhanbad", region: "Dhanbad district", state: "LIVE" },
  products: [
    {
      key: "learning",
      display_name: "Learning",
      short_description: "Find teachers and learning opportunities near you.",
      icon_ref: "learning",
      state: "LIVE",
      entry_url: "https://learning.myraahi.co.in/",
      availability_message: null,
    },
    {
      key: "toto",
      display_name: "ToTo",
      short_description: "Find local transport options for your journey.",
      icon_ref: "toto",
      state: "PAUSED",
      entry_url: "https://myraahi.co.in/toto",
      availability_message: "Temporarily unavailable.",
    },
  ],
};

async function mockHappyApis(page: Page) {
  await page.route("**/api/v1/locations", route =>
    route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ locations }) })
  );
  await page.route("**/api/v1/catalog?location=gomoh", route =>
    route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(gomohCatalog) })
  );
  await page.route("**/api/v1/catalog?location=dhanbad", route =>
    route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(dhanbadCatalog) })
  );
}

async function assertNoHorizontalOverflow(page: Page) {
  const overflow = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    innerWidth: window.innerWidth,
  }));
  expect(overflow.scrollWidth).toBeLessThanOrEqual(overflow.innerWidth + 1);
}

async function assertHeaderDoesNotOverlap(page: Page) {
  const brand = await page.locator(".brand").boundingBox();
  const location = await page.locator("#locationButton").boundingBox();
  expect(brand).not.toBeNull();
  expect(location).not.toBeNull();
  if (!brand || !location) return;
  expect(brand.x + brand.width).toBeLessThanOrEqual(location.x + 1);
}

for (const viewport of [
  { name: "mobile-375", width: 375, height: 667 },
  { name: "mobile-430", width: 430, height: 932 },
  { name: "desktop-1366", width: 1366, height: 768 },
]) {
  test(`location-first shell works at ${viewport.name}`, async ({ page }) => {
    await page.setViewportSize({ width: viewport.width, height: viewport.height });
    await mockHappyApis(page);
    await page.goto("/");

    await expect(page.getByRole("heading", { name: "How can Raahi help you today?" })).toBeVisible();
    await expect(page.locator("#statusAction")).toHaveText("Choose location");
    await expect(page.getByText("Sign in", { exact: true })).toHaveCount(0);
    await assertNoHorizontalOverflow(page);
    await assertHeaderDoesNotOverlap(page);

    await page.getByRole("button", { name: "Choose location" }).first().click();
    await expect(page.getByRole("dialog")).toBeVisible();
    await expect(page.getByRole("button", { name: /Gomoh/ })).toBeVisible();
    await page.getByRole("button", { name: /Gomoh/ }).click();

    await expect(page.getByText("Available in Gomoh")).toBeVisible();
    await expect(page.getByRole("heading", { name: "Learning" })).toBeVisible();
    await expect(page.getByRole("link", { name: /Open Learning/ })).toBeVisible();
    await assertNoHorizontalOverflow(page);
    await assertHeaderDoesNotOverlap(page);

    await page.locator("#locationButton").click();
    await page.locator('[data-location="dhanbad"]').click();
    await expect(page.getByText("Available in Dhanbad")).toBeVisible();
    await expect(page.getByText("Temporarily unavailable.", { exact: true })).toBeVisible();
    await expect(page.getByRole("link", { name: /Open ToTo/ })).toHaveCount(0);

    await page.reload();
    await expect(page.getByText("Available in Dhanbad")).toBeVisible();
    await assertNoHorizontalOverflow(page);
    await assertHeaderDoesNotOverlap(page);

    await page.screenshot({ path: `test-results/${viewport.name}-dhanbad.png`, fullPage: true });
  });
}

test("narrow mobile header survives a long location name", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 700 });
  const longLocations = [{
    id: "loc-long",
    slug: "long-place",
    display_name: "A Very Long Raahi Location Name",
    region: "Jharkhand",
    state: "LIVE",
  }];

  await page.route("**/api/v1/locations", route =>
    route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ locations: longLocations }) })
  );
  await page.route("**/api/v1/catalog?location=long-place", route =>
    route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        location: { slug: "long-place", display_name: "A Very Long Raahi Location Name", region: "Jharkhand", state: "LIVE" },
        products: gomohCatalog.products,
      }),
    })
  );

  await page.goto("/");
  await page.getByRole("button", { name: "Choose location" }).first().click();
  await page.getByRole("button", { name: /A Very Long Raahi Location Name/ }).click();

  await assertNoHorizontalOverflow(page);
  await assertHeaderDoesNotOverlap(page);
  const buttonBox = await page.locator("#locationButton").boundingBox();
  expect(buttonBox).not.toBeNull();
  if (buttonBox) expect(buttonBox.width).toBeLessThanOrEqual(190);
  await page.screenshot({ path: "test-results/mobile-320-long-location.png", fullPage: true });
});

test("catalogue failure stays human and recoverable", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.route("**/api/v1/locations", route =>
    route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ locations }) })
  );
  await page.route("**/api/v1/catalog?location=gomoh", route =>
    route.fulfill({
      status: 503,
      contentType: "application/json",
      body: JSON.stringify({ error: { code: "SERVICE_UNAVAILABLE", message: "Raahi could not load this right now. Please try again." } }),
    })
  );

  await page.goto("/");
  await page.getByRole("button", { name: "Choose location" }).first().click();
  await page.getByRole("button", { name: /Gomoh/ }).click();

  await expect(page.getByRole("heading", { name: "Raahi couldn’t load this location" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Choose another location" })).toBeVisible();
  await expect(page.getByText("SERVICE_UNAVAILABLE")).toHaveCount(0);
  await assertNoHorizontalOverflow(page);
  await page.screenshot({ path: "test-results/mobile-error-recovery.png", fullPage: true });
});
