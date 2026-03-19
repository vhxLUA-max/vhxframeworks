import { EmbedBuilder } from 'discord.js';

export const COLORS = {
  primary:  0x6366f1,
  success:  0x10b981,
  warning:  0xf59e0b,
  danger:   0xef4444,
  muted:    0x374151,
};

export function base(color = COLORS.primary) {
  return new EmbedBuilder()
    .setColor(color)
    .setFooter({ text: 'vhxLUA Hub' })
    .setTimestamp();
}

export function err(msg) {
  return base(COLORS.danger).setDescription(`❌ ${msg}`);
}

export function timeAgo(iso) {
  const diff = (Date.now() - new Date(iso).getTime()) / 1000;
  if (diff < 60)    return `${Math.floor(diff)}s ago`;
  if (diff < 3600)  return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
}

export function fmt(n) {
  return Number(n ?? 0).toLocaleString();
}
