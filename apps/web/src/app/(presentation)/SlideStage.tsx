"use client";

import {
  type ReactNode,
  useCallback,
  useEffect,
  useRef,
  useState,
  useSyncExternalStore,
} from "react";
import { ChevronLeft, ChevronRight, Maximize2, StickyNote } from "lucide-react";

export type Slide = {
  id: string;
  body: ReactNode;
  notes?: ReactNode;
  bg?: string;
};

const VIRTUAL_W = 1280;
const VIRTUAL_H = 720;

const subscribeHash = (cb: () => void) => {
  window.addEventListener("hashchange", cb);
  return () => window.removeEventListener("hashchange", cb);
};
const getHashSnapshot = () => window.location.hash;
const getServerHashSnapshot = () => "";

export function SlideStage({ slides }: { slides: Slide[] }) {
  const hash = useSyncExternalStore(
    subscribeHash,
    getHashSnapshot,
    getServerHashSnapshot,
  );
  const parsed = parseInt(hash.slice(1), 10);
  const idx = Number.isFinite(parsed)
    ? Math.max(0, Math.min(slides.length - 1, parsed - 1))
    : 0;

  const [scale, setScale] = useState(1);
  const [showNotes, setShowNotes] = useState(false);
  const [showHelp, setShowHelp] = useState(false);
  const idxRef = useRef(idx);
  useEffect(() => {
    idxRef.current = idx;
  }, [idx]);

  const go = useCallback(
    (next: number) => {
      const clamped = Math.max(0, Math.min(slides.length - 1, next));
      window.location.hash = `${clamped + 1}`;
    },
    [slides.length],
  );

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.metaKey || e.ctrlKey || e.altKey) return;
      const i = idxRef.current;
      switch (e.key) {
        case "ArrowRight":
        case "PageDown":
        case " ":
          e.preventDefault();
          go(i + 1);
          break;
        case "ArrowLeft":
        case "PageUp":
          e.preventDefault();
          go(i - 1);
          break;
        case "Home":
          e.preventDefault();
          go(0);
          break;
        case "End":
          e.preventDefault();
          go(slides.length - 1);
          break;
        case "p":
        case "P":
          setShowNotes((s) => !s);
          break;
        case "f":
        case "F":
          if (document.fullscreenElement) document.exitFullscreen();
          else document.documentElement.requestFullscreen();
          break;
        case "?":
          setShowHelp((s) => !s);
          break;
        case "Escape":
          setShowHelp(false);
          setShowNotes(false);
          break;
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [go, slides.length]);

  useEffect(() => {
    const compute = () => {
      const w = window.innerWidth;
      const h = window.innerHeight;
      setScale(Math.min(w / VIRTUAL_W, h / VIRTUAL_H));
    };
    compute();
    window.addEventListener("resize", compute);
    return () => window.removeEventListener("resize", compute);
  }, []);

  const slide = slides[idx];

  return (
    <div className="fixed inset-0 overflow-hidden bg-foreground select-none">
      {/* Stage */}
      <div className="absolute inset-0 grid place-items-center">
        <div
          className={`relative origin-center overflow-hidden rounded-md ${slide.bg ?? "bg-background"}`}
          style={{
            width: VIRTUAL_W,
            height: VIRTUAL_H,
            transform: `scale(${scale})`,
          }}
        >
          {slide.body}
        </div>
      </div>

      {/* Top progress bar */}
      <div className="pointer-events-none absolute inset-x-0 top-0 h-1 bg-white/10">
        <div
          className="h-full bg-primary transition-all duration-300"
          style={{ width: `${((idx + 1) / slides.length) * 100}%` }}
        />
      </div>

      {/* Edge click zones for prev/next */}
      <button
        onClick={() => go(idx - 1)}
        aria-label="Previous slide"
        className="group absolute inset-y-0 left-0 w-[15%] cursor-w-resize focus:outline-none"
      >
        <ChevronLeft className="absolute left-4 top-1/2 -translate-y-1/2 h-10 w-10 text-white/0 transition-all duration-200 group-hover:text-white/40" />
      </button>
      <button
        onClick={() => go(idx + 1)}
        aria-label="Next slide"
        className="group absolute inset-y-0 right-0 w-[15%] cursor-e-resize focus:outline-none"
      >
        <ChevronRight className="absolute right-4 top-1/2 -translate-y-1/2 h-10 w-10 text-white/0 transition-all duration-200 group-hover:text-white/40" />
      </button>

      {/* Bottom toolbar */}
      <div className="absolute inset-x-0 bottom-4 flex items-center justify-center gap-2 px-4">
        <div className="flex items-center gap-1 rounded-md bg-white/5 p-1 backdrop-blur-[1px]">
          <button
            onClick={() => go(idx - 1)}
            disabled={idx === 0}
            className="grid h-9 w-9 place-items-center rounded-md text-white/80 transition-all duration-200 hover:bg-white/10 hover:text-white disabled:opacity-30 disabled:hover:bg-transparent"
            aria-label="Previous"
          >
            <ChevronLeft className="h-5 w-5" strokeWidth={2.5} />
          </button>
          <span className="px-3 text-sm font-medium tabular-nums text-white/80">
            {idx + 1} <span className="text-white/40">/ {slides.length}</span>
          </span>
          <button
            onClick={() => go(idx + 1)}
            disabled={idx === slides.length - 1}
            className="grid h-9 w-9 place-items-center rounded-md text-white/80 transition-all duration-200 hover:bg-white/10 hover:text-white disabled:opacity-30 disabled:hover:bg-transparent"
            aria-label="Next"
          >
            <ChevronRight className="h-5 w-5" strokeWidth={2.5} />
          </button>
          <div className="mx-1 h-5 w-px bg-white/10" />
          {slide.notes ? (
            <button
              onClick={() => setShowNotes((s) => !s)}
              className={`grid h-9 w-9 place-items-center rounded-md transition-all duration-200 hover:bg-white/10 ${
                showNotes ? "bg-white/15 text-white" : "text-white/80"
              }`}
              aria-label="Toggle presenter notes"
              title="Presenter notes (P)"
            >
              <StickyNote className="h-4 w-4" strokeWidth={2.25} />
            </button>
          ) : null}
          <button
            onClick={() => {
              if (document.fullscreenElement) document.exitFullscreen();
              else document.documentElement.requestFullscreen();
            }}
            className="grid h-9 w-9 place-items-center rounded-md text-white/80 transition-all duration-200 hover:bg-white/10 hover:text-white"
            aria-label="Toggle fullscreen"
            title="Fullscreen (F)"
          >
            <Maximize2 className="h-4 w-4" strokeWidth={2.25} />
          </button>
        </div>
      </div>

      {/* Slide picker dots */}
      <div className="pointer-events-none absolute inset-x-0 top-3 flex justify-center">
        <div className="pointer-events-auto flex max-w-[60vw] flex-wrap items-center justify-center gap-1.5">
          {slides.map((s, i) => (
            <button
              key={s.id}
              onClick={() => go(i)}
              aria-label={`Go to slide ${i + 1}`}
              className={`h-1.5 rounded-full transition-all duration-200 ${
                i === idx
                  ? "w-6 bg-primary"
                  : "w-1.5 bg-white/20 hover:bg-white/40"
              }`}
            />
          ))}
        </div>
      </div>

      {/* Notes drawer */}
      {showNotes && slide.notes ? (
        <div className="pointer-events-auto absolute right-4 bottom-20 max-w-md rounded-lg bg-background p-6 text-sm leading-relaxed text-foreground">
          <div className="mb-2 text-xs font-bold uppercase tracking-wider text-gray-500">
            Presenter notes
          </div>
          <div className="prose prose-sm max-w-none">{slide.notes}</div>
        </div>
      ) : null}

      {/* Help overlay */}
      <button
        onClick={() => setShowHelp((s) => !s)}
        className="absolute bottom-5 right-5 grid h-9 w-9 place-items-center rounded-md bg-white/5 font-mono text-sm font-bold text-white/60 transition-all duration-200 hover:bg-white/10 hover:text-white"
        aria-label="Keyboard shortcuts"
        title="Keyboard shortcuts (?)"
      >
        ?
      </button>
      {showHelp ? (
        <div
          className="absolute inset-0 grid place-items-center bg-foreground/80"
          onClick={() => setShowHelp(false)}
        >
          <div
            className="rounded-lg bg-background p-8 text-foreground"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="mb-4 text-xs font-bold uppercase tracking-wider text-gray-500">
              Keyboard shortcuts
            </div>
            <dl className="grid grid-cols-[auto_1fr] gap-x-6 gap-y-2 text-sm">
              <dt className="font-mono font-semibold">→ Space PgDn</dt>
              <dd className="text-gray-600">Next slide</dd>
              <dt className="font-mono font-semibold">← PgUp</dt>
              <dd className="text-gray-600">Previous slide</dd>
              <dt className="font-mono font-semibold">Home / End</dt>
              <dd className="text-gray-600">First / last slide</dd>
              <dt className="font-mono font-semibold">P</dt>
              <dd className="text-gray-600">Presenter notes</dd>
              <dt className="font-mono font-semibold">F</dt>
              <dd className="text-gray-600">Fullscreen</dd>
              <dt className="font-mono font-semibold">?</dt>
              <dd className="text-gray-600">This help</dd>
              <dt className="font-mono font-semibold">Esc</dt>
              <dd className="text-gray-600">Close overlay</dd>
            </dl>
          </div>
        </div>
      ) : null}
    </div>
  );
}
