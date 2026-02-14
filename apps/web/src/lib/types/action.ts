export interface ActionResult<T = void> {
  data?: T;
  error?: string;
}
