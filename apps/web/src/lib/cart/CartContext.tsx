"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useReducer,
} from "react";
import type { Cart, CartItem } from "./types";

const STORAGE_KEY = "jirisewa_cart";

interface CartState {
  items: CartItem[];
  hydrated: boolean;
}

type CartAction =
  | { type: "ADD_ITEM"; item: CartItem }
  | { type: "REMOVE_ITEM"; listingId: string }
  | { type: "UPDATE_QUANTITY"; listingId: string; quantityKg: number }
  | { type: "CLEAR" }
  | { type: "HYDRATE"; items: CartItem[] };

function cartReducer(state: CartState, action: CartAction): CartState {
  switch (action.type) {
    case "ADD_ITEM": {
      const existing = state.items.findIndex(
        (i) => i.listingId === action.item.listingId,
      );
      if (existing >= 0) {
        const items = [...state.items];
        items[existing] = {
          ...items[existing],
          quantityKg: items[existing].quantityKg + action.item.quantityKg,
        };
        return { ...state, items };
      }
      return { ...state, items: [...state.items, action.item] };
    }
    case "REMOVE_ITEM":
      return {
        ...state,
        items: state.items.filter((i) => i.listingId !== action.listingId),
      };
    case "UPDATE_QUANTITY": {
      if (action.quantityKg <= 0) {
        return {
          ...state,
          items: state.items.filter((i) => i.listingId !== action.listingId),
        };
      }
      return {
        ...state,
        items: state.items.map((i) =>
          i.listingId === action.listingId
            ? { ...i, quantityKg: action.quantityKg }
            : i,
        ),
      };
    }
    case "CLEAR":
      return { ...state, items: [] };
    case "HYDRATE":
      return { items: action.items, hydrated: true };
    default:
      return state;
  }
}

interface CartContextValue {
  cart: Cart;
  hydrated: boolean;
  addItem: (item: CartItem) => void;
  removeItem: (listingId: string) => void;
  updateQuantity: (listingId: string, quantityKg: number) => void;
  clearCart: () => void;
  itemCount: number;
}

const CartContext = createContext<CartContextValue | null>(null);

export function CartProvider({ children }: { children: React.ReactNode }) {
  const [state, dispatch] = useReducer(cartReducer, {
    items: [],
    hydrated: false,
  });

  // Hydrate from localStorage on mount
  useEffect(() => {
    let items: CartItem[] = [];
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored) {
        const parsed = JSON.parse(stored) as Cart;
        if (parsed && Array.isArray(parsed.items)) {
          items = parsed.items;
        }
      }
    } catch {
      // Ignore corrupted storage
    }
    dispatch({ type: "HYDRATE", items });
  }, []);

  // Persist to localStorage on changes (skip before hydration)
  useEffect(() => {
    if (!state.hydrated) return;
    try {
      localStorage.setItem(
        STORAGE_KEY,
        JSON.stringify({ items: state.items }),
      );
    } catch {
      // Storage full or unavailable
    }
  }, [state.items, state.hydrated]);

  const addItem = useCallback(
    (item: CartItem) => dispatch({ type: "ADD_ITEM", item }),
    [],
  );
  const removeItem = useCallback(
    (listingId: string) => dispatch({ type: "REMOVE_ITEM", listingId }),
    [],
  );
  const updateQuantity = useCallback(
    (listingId: string, quantityKg: number) =>
      dispatch({ type: "UPDATE_QUANTITY", listingId, quantityKg }),
    [],
  );
  const clearCart = useCallback(() => dispatch({ type: "CLEAR" }), []);

  const cart: Cart = useMemo(() => ({ items: state.items }), [state.items]);
  const itemCount = state.items.length;

  const value = useMemo(
    () => ({
      cart,
      hydrated: state.hydrated,
      addItem,
      removeItem,
      updateQuantity,
      clearCart,
      itemCount,
    }),
    [cart, state.hydrated, addItem, removeItem, updateQuantity, clearCart, itemCount],
  );

  return <CartContext.Provider value={value}>{children}</CartContext.Provider>;
}

export function useCart(): CartContextValue {
  const ctx = useContext(CartContext);
  if (!ctx) {
    throw new Error("useCart must be used within a CartProvider");
  }
  return ctx;
}
