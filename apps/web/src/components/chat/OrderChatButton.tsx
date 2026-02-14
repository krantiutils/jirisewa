"use client";

import { useState } from "react";
import { useRouter, useParams } from "next/navigation";
import { useTranslations } from "next-intl";
import { MessageCircle, Loader2 } from "lucide-react";
import { getOrCreateConversation } from "@/lib/actions/chat";
import { Button } from "@/components/ui/Button";

interface OrderChatButtonProps {
  orderId: string;
  otherUserId: string;
  otherUserName: string;
  otherUserRole: "farmer" | "consumer" | "rider";
}

const ROLE_COLORS: Record<string, string> = {
  consumer: "border-blue-300 text-blue-600 hover:bg-blue-50 hover:text-blue-700",
  farmer: "border-emerald-300 text-emerald-600 hover:bg-emerald-50 hover:text-emerald-700",
  rider: "border-amber-300 text-amber-600 hover:bg-amber-50 hover:text-amber-700",
};

export function OrderChatButton({
  orderId,
  otherUserId,
  otherUserName,
  otherUserRole,
}: OrderChatButtonProps) {
  const router = useRouter();
  const { locale } = useParams<{ locale: string }>();
  const t = useTranslations("chat");
  const [loading, setLoading] = useState(false);

  const handleClick = async () => {
    setLoading(true);
    const result = await getOrCreateConversation(orderId, otherUserId);
    if (result.data) {
      router.push(`/${locale}/messages/${result.data.conversationId}`);
    }
    setLoading(false);
  };

  return (
    <Button
      variant="outline"
      className={`w-full h-12 text-sm ${ROLE_COLORS[otherUserRole] ?? ""}`}
      onClick={handleClick}
      disabled={loading}
    >
      {loading ? (
        <Loader2 className="mr-2 h-4 w-4 animate-spin" />
      ) : (
        <MessageCircle className="mr-2 h-4 w-4" />
      )}
      {t("chatWith", { name: otherUserName })}
    </Button>
  );
}
