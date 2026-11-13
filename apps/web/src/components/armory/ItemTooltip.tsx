import type { EquippedItemDTO } from '@blazonguild/types';
import { Coins } from '@/components/game/bits';
import { qualityVar } from '@/lib/game';

/** Faithful in-game tooltip layout: white base lines, green bonuses, yellow item level/set. */
export function ItemTooltipBody({ item }: { item: EquippedItemDTO }) {
  const yellow = '#ffd100';
  const green = '#1eff00';
  return (
    <div className="space-y-0.5 text-[13px] leading-[1.35] text-white">
      <p className="text-[15px] font-semibold" style={{ color: qualityVar(item.quality) }}>
        {item.name}
      </p>
      {item.itemLevel !== null && <p style={{ color: yellow }}>Nivel de objeto {item.itemLevel}</p>}
      {item.binding && <p>{item.binding}</p>}
      {item.uniqueEquipped && <p>{item.uniqueEquipped}</p>}
      {(item.inventoryType || item.itemSubclass) && (
        <p className="flex justify-between gap-6">
          <span>{item.inventoryType}</span>
          <span>{item.itemSubclass}</span>
        </p>
      )}
      {item.weapon && (
        <>
          <p className="flex justify-between gap-6">
            <span>{item.weapon.damage}</span>
            <span>{item.weapon.speed}</span>
          </p>
          <p>{item.weapon.dps}</p>
        </>
      )}
      {item.armor !== null && <p>{item.armor} armadura</p>}
      {item.stats.map((s, i) => (
        <p key={i} style={{ color: s.bonus ? green : s.negative ? '#ff2020' : undefined }}>
          {s.text}
        </p>
      ))}
      {item.enchantments.map((e) => (
        <p key={e} style={{ color: green }}>
          {e}
        </p>
      ))}
      {item.durability && (
        <p>
          Durabilidad {item.durability.current} / {item.durability.max}
        </p>
      )}
      {item.requirements.map((r) => (
        <p key={r}>{r}</p>
      ))}
      {item.spells.map((s) => (
        <p key={s} style={{ color: green }}>
          {s}
        </p>
      ))}
      {item.set && (
        <p className="pt-1" style={{ color: yellow }}>
          {item.set.name} ({item.set.equipped}/{item.set.total})
        </p>
      )}
      {item.description && <p style={{ color: yellow }}>“{item.description}”</p>}
      {item.transmog && <p style={{ color: '#ff80ff' }}>{item.transmog}</p>}
      {item.sellPrice && (
        <p className="flex items-center gap-2 pt-1">
          Precio de venta: <Coins {...item.sellPrice} />
        </p>
      )}
    </div>
  );
}
