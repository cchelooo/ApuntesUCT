import type { Subject } from '../../../domain/catalog/subject';

const TAB_COLORS = ['#7A1F2B', '#2F5C55', '#9C6B12', '#5B3A5C'];
function colorForCareer(career: string): string {
  let hash = 0;
  for (let i = 0; i < career.length; i += 1) {
    hash = career.charCodeAt(i) + ((hash << 5) - hash);
  }
  return TAB_COLORS[Math.abs(hash) % TAB_COLORS.length];
}

interface CatalogCardProps {
  subject: Subject;
}

export function CatalogCard({ subject }: CatalogCardProps) {
  const tabColor = colorForCareer(subject.careerName);

  return (
    <article className="group flex h-full flex-col overflow-hidden rounded-sm border border-catalog-line bg-catalog-paper shadow-[2px_2px_0_0_rgba(27,36,48,0.12)] transition-transform duration-200 ease-out hover:-translate-y-0.5 hover:-rotate-1">
      <div
        className="px-4 py-1.5 font-mono text-xs tracking-wide text-white"
        style={{ backgroundColor: tabColor }}
      >
        {subject.code}
      </div>

      <div className="flex flex-1 flex-col gap-3 px-4 py-4">
        <h3 className="line-clamp-2 font-display text-lg leading-snug text-catalog-ink">
          {subject.name}
        </h3>

        <div className="flex items-center gap-2 text-sm text-catalog-ink/70">
          <span
            className="h-2 w-2 shrink-0 rounded-full"
            style={{ backgroundColor: tabColor }}
            aria-hidden="true"
          />
          <span className="line-clamp-1">{subject.careerName}</span>
        </div>

        <div className="text-sm text-catalog-ink/60">
          Semestre {subject.semester}
        </div>
      </div>

      <div className="flex items-center justify-between border-t border-catalog-line/70 px-4 py-3 text-sm text-catalog-ink/80">
        <span className="line-clamp-1">{subject.professorName}</span>
        <span className="flex shrink-0 items-center gap-1 font-medium">
          <svg
            viewBox="0 0 20 20"
            className="h-4 w-4"
            fill="none"
            stroke="currentColor"
            strokeWidth="1.5"
            aria-hidden="true"
          >
            <path d="M5 3.5h7l3 3v10a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-12a1 1 0 0 1 1-1Z" />
            <path d="M12 3.5v3h3" />
            <path d="M6.5 10.5h7M6.5 13h5" />
          </svg>
          {subject.notesCount}
        </span>
      </div>
    </article>
  );
}
