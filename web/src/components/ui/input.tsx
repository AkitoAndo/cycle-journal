import * as React from "react";
import { cn } from "@/lib/utils";

export type InputProps = React.InputHTMLAttributes<HTMLInputElement>;

const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ className, ...props }, ref) => (
    <input
      ref={ref}
      className={cn(
        "flex h-11 w-full rounded-xl border border-input/80 bg-white/65 px-3.5 py-2 text-[15px] shadow-[inset_0_1px_1px_rgba(33,65,51,0.03)] outline-none transition-all placeholder:text-muted-foreground/65 focus-visible:border-primary/70 focus-visible:bg-white/85 focus-visible:ring-4 focus-visible:ring-primary/12 disabled:cursor-not-allowed disabled:opacity-50",
        className
      )}
      {...props}
    />
  )
);
Input.displayName = "Input";

export { Input };
