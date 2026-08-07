import { PLAY_STORE_URL, APP_STORE_URL, APK_DOWNLOAD_URL } from '../lib/config';

function StoreButton({ href, disabled, icon, topLabel, bottomLabel }) {
  const classes =
    'flex items-center gap-3 rounded-xl border px-5 py-3 transition-colors ' +
    (disabled
      ? 'border-livra-divider bg-livra-surface text-livra-textSecondary cursor-not-allowed'
      : 'border-livra-divider bg-livra-surface hover:border-livra-gold hover:bg-livra-surfaceElevated text-livra-textPrimary');

  const content = (
    <>
      <span className="text-2xl leading-none">{icon}</span>
      <span className="text-left leading-tight">
        <span className="block text-[11px] uppercase tracking-wide text-livra-textSecondary">
          {disabled ? 'Bientôt disponible' : topLabel}
        </span>
        <span className="block text-sm font-semibold">{bottomLabel}</span>
      </span>
    </>
  );

  if (disabled) {
    return <div className={classes}>{content}</div>;
  }
  return (
    <a href={href} target="_blank" rel="noopener noreferrer" className={classes}>
      {content}
    </a>
  );
}

export default function DownloadButtons() {
  // L'APK direct est proposé en priorité s'il est configuré (le plus
  // simple avant une publication officielle sur les stores) ; sinon on
  // retombe sur le Play Store si disponible.
  const androidHref = APK_DOWNLOAD_URL || PLAY_STORE_URL;
  const androidDisabled = !androidHref;

  return (
    <div className="flex flex-wrap gap-4" id="telecharger">
      <StoreButton
        href={androidHref}
        disabled={androidDisabled}
        icon="▶"
        topLabel="Télécharger sur"
        bottomLabel="Android"
      />
      <StoreButton
        href={APP_STORE_URL}
        disabled={!APP_STORE_URL}
        icon=""
        topLabel="Télécharger sur"
        bottomLabel="App Store"
      />
    </div>
  );
}
