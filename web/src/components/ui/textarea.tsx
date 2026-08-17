import * as React from "react";
import { cn } from "@/lib/utils";

export type TextareaProps = React.TextareaHTMLAttributes<HTMLTextAreaElement>;

const Textarea = React.forwardRef<HTMLTextAreaElement, TextareaProps>(
  ({ className, ...props }, ref) => (
    <textarea
      ref={ref}
      className={cn(
        "flex w-full resize-y rounded-xl border border-input/80 bg-white/65 px-3.5 py-3 text-[15px] leading-relaxed shadow-[inset_0_1px_1px_rgba(89,71,56,0.03)] outline-none transition-all placeholder:text-muted-foreground/65 focus-visible:border-primary/70 focus-visible:bg-white/85 focus-visible:ring-4 focus-visible:ring-primary/12 disabled:cursor-not-allowed disabled:opacity-50",
        className
      )}
      {...props}
    />
  )
);
Textarea.displayName = "Textarea";

export { Textarea };
