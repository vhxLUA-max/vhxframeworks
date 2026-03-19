import { SlashCommandBuilder, PermissionFlagsBits } from 'discord.js';
import { supabase } from '../supabase.js';
import { base, err, timeAgo, fmt, COLORS } from '../embeds.js';

const ADMIN_IDS = (process.env.ADMIN_USER_IDS ?? '').split(',').map(s => s.trim()).filter(Boolean);
const isAdmin = (id) => ADMIN_IDS.includes(id);

const GAMES = ['Pixel Blade', 'Loot Hero', 'Flick', 'Survive Lava'];

export const commands = [

  {
    data: new SlashCommandBuilder()
      .setName('stats')
      .setDescription('Show overall dashboard stats'),
    async execute(i) {
      await i.deferReply();
      const [{ data: execs }, { data: users }] = await Promise.all([
        supabase.from('game_executions').select('count,daily_count,daily_reset_at,last_executed_at'),
        supabase.from('unique_users').select('roblox_user_id,first_seen'),
      ]);
      const total = (execs ?? []).reduce((s, e) => s + (e.count ?? 0), 0);
      const today = new Date().toISOString().slice(0, 10);
      const daily = (execs ?? []).reduce((s, e) => s + (e.daily_reset_at?.slice(0, 10) === today ? (e.daily_count ?? 0) : 0), 0);
      const since24 = new Date(Date.now() - 86400000).toISOString();
      const active = new Set((users ?? []).filter(u => u.first_seen >= since24).map(u => u.roblox_user_id)).size;
      const last = (execs ?? []).sort((a, b) => new Date(b.last_executed_at) - new Date(a.last_executed_at))[0];
      const embed = base()
        .setTitle('📊 Dashboard Stats')
        .addFields(
          { name: '⚡ Total Executions', value: fmt(total),   inline: true },
          { name: '📅 Today',            value: fmt(daily),   inline: true },
          { name: '👥 New Users (24h)',   value: fmt(active),  inline: true },
          { name: '🕒 Last Execution',    value: last ? timeAgo(last.last_executed_at) : '—', inline: true },
          { name: '🎮 Active Scripts',    value: `${(execs ?? []).length}`, inline: true },
        );
      await i.editReply({ embeds: [embed] });
    },
  },

  {
    data: new SlashCommandBuilder()
      .setName('game')
      .setDescription('Show stats for a specific game')
      .addStringOption(o => o.setName('name').setDescription('Game name').setRequired(true).addChoices(...GAMES.map(g => ({ name: g, value: g })))),
    async execute(i) {
      await i.deferReply();
      const name = i.options.getString('name');
      const { data } = await supabase.from('game_executions').select('*').eq('game_name', name);
      if (!data?.length) return i.editReply({ embeds: [err(`No data found for **${name}**`)] });
      const row = data[0];
      const embed = base()
        .setTitle(`🎮 ${name}`)
        .addFields(
          { name: '⚡ Total Executions', value: fmt(row.count),    inline: true },
          { name: '🕒 Last Execution',    value: timeAgo(row.last_executed_at), inline: true },
        );
      await i.editReply({ embeds: [embed] });
    },
  },

  {
    data: new SlashCommandBuilder()
      .setName('user')
      .setDescription('Look up a user by their token')
      .addStringOption(o => o.setName('token').setDescription('User token (e.g. VOID3847)').setRequired(true)),
    async execute(i) {
      await i.deferReply();
      const token = i.options.getString('token').toUpperCase();
      const { data: tokenRow } = await supabase.from('user_tokens').select('roblox_user_id,roblox_username').eq('token', token).maybeSingle();
      if (!tokenRow) return i.editReply({ embeds: [err('Token not found.')] });
      const { data: rows } = await supabase.from('unique_users').select('*').eq('roblox_user_id', tokenRow.roblox_user_id);
      if (!rows?.length) return i.editReply({ embeds: [err('No execution data found for this user.')] });
      const total = rows.reduce((s, r) => s + (r.execution_count ?? 0), 0);
      const earliest = rows.reduce((a, b) => new Date(a.first_seen) < new Date(b.first_seen) ? a : b).first_seen;
      const latest   = rows.reduce((a, b) => new Date(a.last_seen)  > new Date(b.last_seen)  ? a : b).last_seen;
      const gameLines = rows.sort((a, b) => b.execution_count - a.execution_count)
        .map(r => `**${r.game_name ?? `Place ${r.place_id}`}** — ${fmt(r.execution_count)} execs`).join('\n');
      const embed = base()
        .setTitle(`👤 ${tokenRow.roblox_username}`)
        .setURL(`https://www.roblox.com/users/${tokenRow.roblox_user_id}/profile`)
        .addFields(
          { name: '⚡ Total Executions', value: fmt(total),         inline: true },
          { name: '🎮 Games Played',     value: `${rows.length}`,   inline: true },
          { name: '📅 First Seen',       value: timeAgo(earliest),  inline: true },
          { name: '🕒 Last Seen',        value: timeAgo(latest),    inline: true },
          { name: '🗂️ Game Breakdown',    value: gameLines || '—',   inline: false },
        );
      await i.editReply({ embeds: [embed] });
    },
  },

  {
    data: new SlashCommandBuilder()
      .setName('whois')
      .setDescription('Look up a user by Roblox username')
      .addStringOption(o => o.setName('username').setDescription('Roblox username').setRequired(true)),
    async execute(i) {
      await i.deferReply();
      const username = i.options.getString('username');
      const { data: rows } = await supabase.from('unique_users').select('*').ilike('username', username);
      if (!rows?.length) return i.editReply({ embeds: [err(`No data found for **${username}**. They must run a script in-game first.`)] });
      const total = rows.reduce((s, r) => s + (r.execution_count ?? 0), 0);
      const earliest = rows.reduce((a, b) => new Date(a.first_seen) < new Date(b.first_seen) ? a : b).first_seen;
      const latest   = rows.reduce((a, b) => new Date(a.last_seen)  > new Date(b.last_seen)  ? a : b).last_seen;
      const gameLines = rows.sort((a, b) => b.execution_count - a.execution_count)
        .map(r => `**${r.game_name ?? `Place ${r.place_id}`}** — ${fmt(r.execution_count)} execs`).join('\n');
      const embed = base()
        .setTitle(`👤 ${rows[0].username}`)
        .setURL(`https://www.roblox.com/users/${rows[0].roblox_user_id}/profile`)
        .addFields(
          { name: '⚡ Total Executions', value: fmt(total),         inline: true },
          { name: '🎮 Games Played',     value: `${rows.length}`,   inline: true },
          { name: '📅 First Seen',       value: timeAgo(earliest),  inline: true },
          { name: '🕒 Last Seen',        value: timeAgo(latest),    inline: true },
          { name: '🗂️ Game Breakdown',    value: gameLines || '—',   inline: false },
        );
      await i.editReply({ embeds: [embed] });
    },
  },

  {
    data: new SlashCommandBuilder()
      .setName('ban')
      .setDescription('Ban a user from vhxLUA scripts [Admin only]')
      .addStringOption(o => o.setName('username').setDescription('Roblox username').setRequired(true))
      .addStringOption(o => o.setName('reason').setDescription('Ban reason').setRequired(false)),
    async execute(i) {
      if (!isAdmin(i.user.id)) return i.reply({ embeds: [err('Admin only.')], ephemeral: true });
      await i.deferReply();
      const username = i.options.getString('username');
      const reason   = i.options.getString('reason') ?? null;
      const { data: rows } = await supabase.from('unique_users').select('roblox_user_id,username').ilike('username', username).limit(1);
      const user = rows?.[0];
      if (!user) return i.editReply({ embeds: [err(`**${username}** not found. They must run a script in-game first.`)] });
      const { error } = await supabase.from('banned_users').insert({ roblox_user_id: user.roblox_user_id, username: user.username, reason });
      if (error) return i.editReply({ embeds: [err(error.message)] });
      const embed = base(COLORS.danger)
        .setTitle('🔨 User Banned')
        .addFields(
          { name: 'Username', value: `@${user.username}`, inline: true },
          { name: 'Reason',   value: reason ?? 'No reason provided', inline: true },
          { name: 'By',       value: `<@${i.user.id}>`, inline: true },
        );
      await i.editReply({ embeds: [embed] });
    },
  },

  {
    data: new SlashCommandBuilder()
      .setName('unban')
      .setDescription('Unban a user [Admin only]')
      .addStringOption(o => o.setName('username').setDescription('Roblox username').setRequired(true)),
    async execute(i) {
      if (!isAdmin(i.user.id)) return i.reply({ embeds: [err('Admin only.')], ephemeral: true });
      await i.deferReply();
      const username = i.options.getString('username');
      const { data: rows } = await supabase.from('banned_users').select('id,username').ilike('username', username).limit(1);
      if (!rows?.length) return i.editReply({ embeds: [err(`**${username}** is not banned.`)] });
      await supabase.from('banned_users').delete().eq('id', rows[0].id);
      await i.editReply({ embeds: [base(COLORS.success).setDescription(`✅ **@${rows[0].username}** has been unbanned.`)] });
    },
  },

  {
    data: new SlashCommandBuilder()
      .setName('bans')
      .setDescription('List all banned users [Admin only]'),
    async execute(i) {
      if (!isAdmin(i.user.id)) return i.reply({ embeds: [err('Admin only.')], ephemeral: true });
      await i.deferReply();
      const { data } = await supabase.from('banned_users').select('*').order('created_at', { ascending: false });
      if (!data?.length) return i.editReply({ embeds: [base().setDescription('No banned users.')] });
      const lines = data.slice(0, 20).map(b => `**@${b.username ?? b.roblox_user_id}** — ${b.reason ?? 'No reason'} *(${timeAgo(b.created_at)})*`).join('\n');
      const embed = base(COLORS.danger)
        .setTitle(`🚫 Banned Users (${data.length})`)
        .setDescription(lines);
      await i.editReply({ embeds: [embed] });
    },
  },

  {
    data: new SlashCommandBuilder()
      .setName('tokens')
      .setDescription('List all verified tokens [Admin only]'),
    async execute(i) {
      if (!isAdmin(i.user.id)) return i.reply({ embeds: [err('Admin only.')], ephemeral: true });
      await i.deferReply();
      const { data } = await supabase.from('user_tokens').select('*').order('updated_at', { ascending: false });
      if (!data?.length) return i.editReply({ embeds: [base().setDescription('No verified tokens.')] });
      const lines = data.slice(0, 20).map(t => `**@${t.roblox_username}** — \`${t.token}\` *(${timeAgo(t.updated_at)})*`).join('\n');
      const embed = base()
        .setTitle(`🔑 Verified Tokens (${data.length})`)
        .setDescription(lines);
      await i.editReply({ embeds: [embed] });
    },
  },

  {
    data: new SlashCommandBuilder()
      .setName('changelog')
      .setDescription('Show latest changelog entries'),
    async execute(i) {
      await i.deferReply();
      const { data } = await supabase.from('changelog').select('*').order('date', { ascending: false }).limit(8);
      if (!data?.length) return i.editReply({ embeds: [base().setDescription('No changelog entries yet.')] });
      const TYPE_EMOJI = { new: '🟢', update: '🔵', fix: '🔴' };
      const lines = data.map(e => `${TYPE_EMOJI[e.type] ?? '⚪'} **[${e.game}] ${e.title}** — ${e.body ? e.body : ''} \`${e.date}\``).join('\n');
      const embed = base()
        .setTitle('📋 Changelog')
        .setDescription(lines);
      await i.editReply({ embeds: [embed] });
    },
  },

  {
    data: new SlashCommandBuilder()
      .setName('addchangelog')
      .setDescription('Add a changelog entry [Admin only]')
      .addStringOption(o => o.setName('game').setDescription('Game name').setRequired(true).addChoices(...[...GAMES, 'General'].map(g => ({ name: g, value: g }))))
      .addStringOption(o => o.setName('type').setDescription('Entry type').setRequired(true).addChoices({ name: 'new', value: 'new' }, { name: 'update', value: 'update' }, { name: 'fix', value: 'fix' }))
      .addStringOption(o => o.setName('title').setDescription('Entry title').setRequired(true))
      .addStringOption(o => o.setName('body').setDescription('Description').setRequired(false)),
    async execute(i) {
      if (!isAdmin(i.user.id)) return i.reply({ embeds: [err('Admin only.')], ephemeral: true });
      await i.deferReply();
      const game  = i.options.getString('game');
      const type  = i.options.getString('type');
      const title = i.options.getString('title');
      const body  = i.options.getString('body') ?? '';
      const date  = new Date().toISOString().slice(0, 10);
      const { error } = await supabase.from('changelog').insert({ game, type, title, body, date });
      if (error) return i.editReply({ embeds: [err(error.message)] });
      const embed = base(COLORS.success)
        .setTitle('✅ Changelog Entry Added')
        .addFields(
          { name: 'Game',  value: game,  inline: true },
          { name: 'Type',  value: type,  inline: true },
          { name: 'Title', value: title, inline: false },
          ...(body ? [{ name: 'Description', value: body, inline: false }] : []),
        );
      await i.editReply({ embeds: [embed] });
    },
  },

];
