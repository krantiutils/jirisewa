import { test, expect } from "@playwright/test";
import {
  mockSupabaseRoutes,
  injectAuthCookies,
  DEMO_CONSUMER_ID,
  DEMO_FARMER_ID,
} from "./helpers/supabase-mock";

const DEMO_CONVERSATION_ID = "cccccccc-0000-0000-0000-000000000001";
const DEMO_ORDER_ID = "bbbbbbbb-0000-0000-0000-000000000001";

const demoConversation = {
  id: DEMO_CONVERSATION_ID,
  order_id: DEMO_ORDER_ID,
  participant_ids: [DEMO_CONSUMER_ID, DEMO_FARMER_ID],
  created_at: "2026-02-14T10:00:00Z",
};

const demoMessages = [
  {
    id: "msg-001",
    conversation_id: DEMO_CONVERSATION_ID,
    sender_id: DEMO_CONSUMER_ID,
    content: "Hello, is the produce ready?",
    message_type: "text",
    read_at: "2026-02-14T10:01:00Z",
    created_at: "2026-02-14T10:00:00Z",
    sender: { name: "Test Consumer", avatar_url: null },
  },
  {
    id: "msg-002",
    conversation_id: DEMO_CONVERSATION_ID,
    sender_id: DEMO_FARMER_ID,
    content: "Yes, fresh tomatoes are packed!",
    message_type: "text",
    read_at: null,
    created_at: "2026-02-14T10:02:00Z",
    sender: { name: "Demo Farmer", avatar_url: null },
  },
];

const demoOtherUser = {
  id: DEMO_FARMER_ID,
  name: "Demo Farmer",
  avatar_url: null,
  role: "farmer",
};

test.describe("Chat — message list page", () => {
  test.beforeEach(async ({ page }) => {
    // Mock chat conversation data before the general mocks
    await page.route("**/rest/v1/chat_conversations*", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify([demoConversation]),
      });
    });

    await page.route("**/rest/v1/chat_messages*", async (route) => {
      const url = route.request().url();
      if (url.includes("count")) {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          headers: { "content-range": "0-0/1" },
          body: JSON.stringify([]),
        });
        return;
      }
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify(demoMessages),
      });
    });

    await mockSupabaseRoutes(page);
    await injectAuthCookies(page);
  });

  test("displays the messages page title", async ({ page }) => {
    await page.goto("/en/messages");

    await expect(page.locator("h1")).toContainText("Messages");

    await expect(page).toHaveScreenshot("chat-list.png");
  });

  test("shows empty state when no conversations", async ({ page }) => {
    // Override: return empty conversations
    await page.route("**/rest/v1/chat_conversations*", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify([]),
      });
    });

    await page.goto("/en/messages");

    await expect(page.getByText("No messages yet")).toBeVisible();

    await expect(page).toHaveScreenshot("chat-list-empty.png");
  });
});

test.describe("Chat — conversation view", () => {
  test.beforeEach(async ({ page }) => {
    await page.route("**/rest/v1/chat_conversations*", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify([demoConversation]),
      });
    });

    await page.route("**/rest/v1/chat_messages*", async (route) => {
      const url = route.request().url();
      if (url.includes("count")) {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          headers: { "content-range": "0-0/0" },
          body: JSON.stringify([]),
        });
        return;
      }
      if (route.request().method() === "PATCH") {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify([]),
        });
        return;
      }
      if (route.request().method() === "POST") {
        await route.fulfill({
          status: 201,
          contentType: "application/json",
          body: JSON.stringify({
            id: "msg-new",
            conversation_id: DEMO_CONVERSATION_ID,
            sender_id: DEMO_CONSUMER_ID,
            content: "Test message",
            message_type: "text",
            read_at: null,
            created_at: new Date().toISOString(),
          }),
        });
        return;
      }
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify(demoMessages),
      });
    });

    await page.route("**/rest/v1/users*", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify([demoOtherUser]),
      });
    });

    await mockSupabaseRoutes(page);
    await injectAuthCookies(page);
  });

  test("displays conversation with messages", async ({ page }) => {
    await page.goto(`/en/messages/${DEMO_CONVERSATION_ID}`);

    // Wait for messages to load
    await page.waitForTimeout(1000);

    // Should show the other user's name
    await expect(page.getByText("Demo Farmer")).toBeVisible();

    // Should show messages
    await expect(page.getByText("Hello, is the produce ready?")).toBeVisible();
    await expect(page.getByText("Yes, fresh tomatoes are packed!")).toBeVisible();

    await expect(page).toHaveScreenshot("chat-conversation.png");
  });

  test("has message input and send button", async ({ page }) => {
    await page.goto(`/en/messages/${DEMO_CONVERSATION_ID}`);

    await page.waitForTimeout(1000);

    const input = page.getByPlaceholder("Type a message...");
    await expect(input).toBeVisible();

    const sendButton = page.getByRole("button", { name: /send/i });
    await expect(sendButton).toBeVisible();

    await expect(page).toHaveScreenshot("chat-input.png");
  });

  test("has back to messages link", async ({ page }) => {
    await page.goto(`/en/messages/${DEMO_CONVERSATION_ID}`);
    await page.waitForTimeout(1000);

    // The back arrow link should be present
    const backLink = page.locator('a[href="/en/messages"]');
    await expect(backLink).toBeVisible();
  });
});
