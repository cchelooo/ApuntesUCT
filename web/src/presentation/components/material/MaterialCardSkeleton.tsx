export function MaterialCardSkeleton() {
  return (
    <div
      data-testid="material-card-skeleton"
      aria-hidden="true"
      className="flex animate-pulse items-start gap-4 rounded-xs border border-catalog-line bg-catalog-paperMuted p-4 motion-reduce:animate-none"
    >
      <div className="h-6 w-6 shrink-0 rounded-xs bg-catalog-line/60" />
      <div className="flex-1 space-y-2">
        <div className="h-5 w-3/4 rounded-xs bg-catalog-line/60" />
        <div className="h-4 w-1/2 rounded-xs bg-catalog-line/40" />
        <div className="h-4 w-1/3 rounded-xs bg-catalog-line/40" />
      </div>
      <div className="space-y-2">
        <div className="h-5 w-16 rounded-xs bg-catalog-line/60" />
        <div className="ml-auto h-4 w-10 rounded-xs bg-catalog-line/40" />
      </div>
    </div>
  );
}
