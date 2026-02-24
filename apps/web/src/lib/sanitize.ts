import DOMPurify from "isomorphic-dompurify";

const ALLOWED_TAGS = [
  "p", "br", "strong", "em", "b", "i",
  "h2", "h3",
  "ul", "ol", "li",
  "a",
  "blockquote",
  "img",
];

const ALLOWED_ATTR = ["href", "target", "rel", "src", "alt", "width", "height"];

export function sanitizeHTML(dirty: string): string {
  return DOMPurify.sanitize(dirty, {
    ALLOWED_TAGS,
    ALLOWED_ATTR,
    ADD_ATTR: ["target"],
    ALLOWED_URI_REGEXP: /^https?:\/\//i,
  });
}

export function stripHTML(html: string): string {
  return DOMPurify.sanitize(html, { ALLOWED_TAGS: [] });
}
