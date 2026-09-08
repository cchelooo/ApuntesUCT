interface PendingPageProps {
  title: string
}

export function PendingPage({ title }: PendingPageProps) {
  return (
    <section>
      <h1>{title}</h1>
      <p>{title} pendiente.</p>
    </section>
  )
}