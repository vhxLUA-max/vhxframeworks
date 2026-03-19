import { SlashCommandBuilder, PermissionFlagsBits } from 'discord.js';
import { supabase } from '../supabase.js';
import { base, err, timeAgo, fmt, COLORS } from '../embeds.js';

const ADMIN_IDS = (process.env.ADMIN_USER_IDS ?? '').split(',').map(s => s.trim()).filter(Boolean);
const isAdmin = (id) => ADMIN_IDS.includes(id);

const PLACE_NAMES = {
  18172550962:     'Pixel Blade',
  18172553902:     'Pixel Blade',
  133884972346775: 'Pixel Blade',
  138013005633222: 'Loot Hero',
  77439980360504:  'Loot Hero',
  119987266683883: 'Survive Lava',
  136801880565837: 'Flick',
  123974602339071: 'UNC Tester',
};

const gameName = (r) => r.game_name || PLACE_NAMES[r.place_id] || `Place ${r.place_id}`;

const logAction = async (i, action, details) => {
  await supabase.from('audit_log').insert({ action, details, username: i.user.username }).catch(() => {});
};

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
        .setDescription([
          `> ⚡ **Total Executions** — \`${fmt(total)}\``,
          `> 📅 **Today** — \`${fmt(daily)}\``,
          `> 👥 **New Users (24h)** — \`${fmt(active)}\``,
          `> 🕒 **Last Execution** — \`${last ? timeAgo(last.last_executed_at) : '—'}\``,
          `> 🎮 **Active Scripts** — \`3\``,
        ].join('\n'));
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
        .setDescription([
          `> ⚡ **Total Executions** — \`${fmt(row.count)}\``,
          `> 🕒 **Last Execution** — \`${timeAgo(row.last_executed_at)}\``,
        ].join('\n'));
      await i.editReply({ embeds: [embed] });
    },
  },

  {
    data: new SlashCommandBuilder()
      .setName('user').setDefaultMemberPermissions(0)
      .setDescription('Look up a user by their token')
      .addStringOption(o => o.setName('token').setDescription('User token (e.g. VOID3847)').setRequired(true)),
    async execute(i) {
      await i.deferReply({ ephemeral: true });
      const token = i.options.getString('token').toUpperCase();
      const { data: tokenRow } = await supabase.from('user_tokens').select('roblox_user_id,roblox_username').eq('token', token).maybeSingle();
      if (!tokenRow) return i.editReply({ embeds: [err('Token not found.')] });
      const { data: rows } = await supabase.from('unique_users').select('*').eq('roblox_user_id', tokenRow.roblox_user_id);
      if (!rows?.length) return i.editReply({ embeds: [err('No execution data found for this user.')] });
      const total = rows.reduce((s, r) => s + (r.execution_count ?? 0), 0);
      const earliest = rows.reduce((a, b) => new Date(a.first_seen) < new Date(b.first_seen) ? a : b).first_seen;
      const latest   = rows.reduce((a, b) => new Date(a.last_seen)  > new Date(b.last_seen)  ? a : b).last_seen;
      const gameLines = rows.sort((a, b) => b.execution_count - a.execution_count)
        .map(r => `> 🎮 **${gameName(r)}** — \`${fmt(r.execution_count)} execs\``).join('\n');
      const embed = base()
        .setTitle(`👤 ${tokenRow.roblox_username}`)
        .setURL(`https://www.roblox.com/users/${tokenRow.roblox_user_id}/profile`)
        .setDescription([
          `> ⚡ **Total Executions** — \`${fmt(total)}\``,
          `> 🎮 **Games Played** — \`${rows.length}\``,
          `> 📅 **First Seen** — \`${timeAgo(earliest)}\``,
          `> 🕒 **Last Seen** — \`${timeAgo(latest)}\``,
          ``,
          `**Game Breakdown**`,
          gameLines || '> —',
        ].join('\n'));
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
        .map(r => `> 🎮 **${gameName(r)}** — \`${fmt(r.execution_count)} execs\``).join('\n');
      const embed = base()
        .setTitle(`👤 ${rows[0].username}`)
        .setURL(`https://www.roblox.com/users/${rows[0].roblox_user_id}/profile`)
        .setDescription([
          `> ⚡ **Total Executions** — \`${fmt(total)}\``,
          `> 🎮 **Games Played** — \`${rows.length}\``,
          `> 📅 **First Seen** — \`${timeAgo(earliest)}\``,
          `> 🕒 **Last Seen** — \`${timeAgo(latest)}\``,
          ``,
          `**Game Breakdown**`,
          gameLines || '> —',
        ].join('\n'));
      await i.editReply({ embeds: [embed] });
    },
  },

  {
    data: new SlashCommandBuilder()
      .setName('ban').setDefaultMemberPermissions(0)
      .setDescription('Ban a user from vhxLUA scripts [Admin only]')
      .addStringOption(o => o.setName('username').setDescription('Roblox username').setRequired(true))
      .addStringOption(o => o.setName('reason').setDescription('Ban reason').setRequired(false)),
    async execute(i) {
      if (!isAdmin(i.user.id)) return i.reply({ embeds: [err('Admin only.')], ephemeral: true });
      await i.deferReply({ ephemeral: true });
      const username = i.options.getString('username');
      const reason   = i.options.getString('reason') ?? null;
      const { data: rows } = await supabase.from('unique_users').select('roblox_user_id,username').ilike('username', username).limit(1);
      const user = rows?.[0];
      if (!user) return i.editReply({ embeds: [err(`**${username}** not found. They must run a script in-game first.`)] });
      const { error } = await supabase.from('banned_users').insert({ roblox_user_id: user.roblox_user_id, username: user.username, reason });
      if (error) return i.editReply({ embeds: [err(error.message)] });
      const embed = base(COLORS.danger)
        .setTitle('🔨 User Banned')
        .setDescription([
          `> 👤 **User** — @${user.username}`,
          `> 📋 **Reason** — ${reason ?? 'No reason provided'}`,
          `> 🛡️ **Banned by** — <@${i.user.id}>`,
        ].join('\n'));
      await i.editReply({ embeds: [embed] });
    },
  },

  {
    data: new SlashCommandBuilder()
      .setName('unban').setDefaultMemberPermissions(0)
      .setDescription('Unban a user [Admin only]')
      .addStringOption(o => o.setName('username').setDescription('Roblox username').setRequired(true)),
    async execute(i) {
      if (!isAdmin(i.user.id)) return i.reply({ embeds: [err('Admin only.')], ephemeral: true });
      await i.deferReply({ ephemeral: true });
      const username = i.options.getString('username');
      const { data: rows } = await supabase.from('banned_users').select('id,username').ilike('username', username).limit(1);
      if (!rows?.length) return i.editReply({ embeds: [err(`**${username}** is not banned.`)] });
      await supabase.from('banned_users').delete().eq('id', rows[0].id);
      await i.editReply({ embeds: [base(COLORS.success).setDescription(`✅ **@${rows[0].username}** has been unbanned.`)] });
    },
  },

  {
    data: new SlashCommandBuilder()
      .setName('bans').setDefaultMemberPermissions(0)
      .setDescription('List all banned users [Admin only]'),
    async execute(i) {
      if (!isAdmin(i.user.id)) return i.reply({ embeds: [err('Admin only.')], ephemeral: true });
      await i.deferReply({ ephemeral: true });
      const { data } = await supabase.from('banned_users').select('*').order('created_at', { ascending: false });
      if (!data?.length) return i.editReply({ embeds: [base().setDescription('No banned users.')] });
      const lines = data.slice(0, 20).map(b => `> 🚫 **@${b.username ?? b.roblox_user_id}** — \`${b.reason ?? 'No reason'}\` *(${timeAgo(b.created_at)})*`).join('\n');
      const embed = base(COLORS.danger)
        .setTitle(`🚫 Banned Users (${data.length})`)
        .setDescription(lines);
      await i.editReply({ embeds: [embed] });
    },
  },

  {
    data: new SlashCommandBuilder()
      .setName('tokens').setDefaultMemberPermissions(0)
      .setDescription('List all verified tokens [Admin only]'),
    async execute(i) {
      if (!isAdmin(i.user.id)) return i.reply({ embeds: [err('Admin only.')], ephemeral: true });
      await i.deferReply({ ephemeral: true });
      const { data } = await supabase.from('user_tokens').select('*').order('updated_at', { ascending: false });
      if (!data?.length) return i.editReply({ embeds: [base().setDescription('No verified tokens.')] });
      const embed = base().setTitle(`🔑 Verified Tokens (${data.length})`).setDescription(
        data.slice(0, 20).map(t => `> **@${t.roblox_username}** *(${timeAgo(t.updated_at)})*`).join('\n')
      );
      await i.editReply({ embeds: [embed] });
      for (const t of data.slice(0, 20)) {
        await i.followUp({ content: `**@${t.roblox_username}**\n\`\`\`${t.token}\`\`\``, ephemeral: true });
      }
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
      const lines = data.map(e => `> ${TYPE_EMOJI[e.type] ?? '⚪'} **[${e.game}] ${e.title}**${e.body ? ` — ${e.body}` : ''} \`${e.date}\``).join('\n');
      const embed = base()
        .setTitle('📋 Changelog')
        .setDescription(lines);
      await i.editReply({ embeds: [embed] });
    },
  },

  {
    data: new SlashCommandBuilder()
      .setName('addchangelog').setDefaultMemberPermissions(0)
      .setDescription('Add a changelog entry [Admin only]')
      .addStringOption(o => o.setName('game').setDescription('Game name').setRequired(true).addChoices(...[...GAMES, 'General'].map(g => ({ name: g, value: g }))))
      .addStringOption(o => o.setName('type').setDescription('Entry type').setRequired(true).addChoices({ name: 'new', value: 'new' }, { name: 'update', value: 'update' }, { name: 'fix', value: 'fix' }))
      .addStringOption(o => o.setName('title').setDescription('Entry title').setRequired(true))
      .addStringOption(o => o.setName('body').setDescription('Description').setRequired(false)),
    async execute(i) {
      if (!isAdmin(i.user.id)) return i.reply({ embeds: [err('Admin only.')], ephemeral: true });
      await i.deferReply({ ephemeral: true });
      const game  = i.options.getString('game');
      const type  = i.options.getString('type');
      const title = i.options.getString('title');
      const body  = i.options.getString('body') ?? '';
      const date  = new Date().toISOString().slice(0, 10);
      const { error } = await supabase.from('changelog').insert({ game, type, title, body, date });
      if (error) return i.editReply({ embeds: [err(error.message)] });
      const embed = base(COLORS.success)
        .setTitle('✅ Changelog Entry Added')
        .setDescription([
          `> 🎮 **Game** — \`${game}\``,
          `> 🏷️ **Type** — \`${type}\``,
          `> 📝 **Title** — ${title}`,
          ...(body ? [`> 💬 **Description** — ${body}`] : []),
        ].join('\n'));
      await i.editReply({ embeds: [embed] });
    },
  },

  {
    data: new SlashCommandBuilder()
      .setName('softban').setDefaultMemberPermissions(0)
      .setDescription('Temporarily ban a user with auto-unban [Admin only]')
      .addStringOption(o => o.setName('username').setDescription('Roblox username').setRequired(true))
      .addIntegerOption(o => o.setName('duration').setDescription('Duration').setRequired(true).setMinValue(1))
      .addStringOption(o => o.setName('unit').setDescription('Unit').setRequired(true).addChoices({ name: 'hours', value: 'hours' }, { name: 'days', value: 'days' }))
      .addStringOption(o => o.setName('reason').setDescription('Reason').setRequired(false)),
    async execute(i) {
      if (!isAdmin(i.user.id)) return i.reply({ embeds: [err('Admin only.')], ephemeral: true });
      await i.deferReply({ ephemeral: true });
      const username = i.options.getString('username');
      const duration = i.options.getInteger('duration');
      const unit     = i.options.getString('unit');
      const reason   = i.options.getString('reason') ?? null;
      const ms       = duration * (unit === 'hours' ? 3600000 : 86400000);
      const unbanAt  = new Date(Date.now() + ms).toISOString();

      const { data: rows } = await supabase.from('unique_users').select('roblox_user_id,username').ilike('username', username).limit(1);
      const user = rows?.[0];
      if (!user) return i.editReply({ embeds: [err(`**${username}** not found. They must run a script in-game first.`)] });

      const { error } = await supabase.from('banned_users').insert({
        roblox_user_id: user.roblox_user_id,
        username: user.username,
        reason: reason ? `[SOFTBAN until ${new Date(unbanAt).toUTCString()}] ${reason}` : `[SOFTBAN until ${new Date(unbanAt).toUTCString()}]`,
        unban_at: unbanAt,
      });
      if (error) return i.editReply({ embeds: [err(error.message)] });

      await logAction(i, 'softban', { username: user.username, roblox_user_id: user.roblox_user_id, duration: `${duration} ${unit}`, reason, unban_at: unbanAt });

      const embed = base(COLORS.warning)
        .setTitle('⏱️ Softban Applied')
        .setDescription([
          `> 👤 **User** — @${user.username}`,
          `> ⏳ **Duration** — \`${duration} ${unit}\``,
          `> 📅 **Unbans At** — \`${new Date(unbanAt).toUTCString()}\``,
          `> 📋 **Reason** — ${reason ?? 'No reason provided'}`,
        ].join('\n'));
      await i.editReply({ embeds: [embed] });
    },
  },

  {
    data: new SlashCommandBuilder()
      .setName('banlog').setDefaultMemberPermissions(0)
      .setDescription('Show ban audit trail [Admin only]')
      .addIntegerOption(o => o.setName('limit').setDescription('Number of entries (default 10)').setRequired(false).setMinValue(1).setMaxValue(50)),
    async execute(i) {
      if (!isAdmin(i.user.id)) return i.reply({ embeds: [err('Admin only.')], ephemeral: true });
      await i.deferReply({ ephemeral: true });
      const limit = i.options.getInteger('limit') ?? 10;
      const { data } = await supabase.from('audit_log').select('*').in('action', ['ban_user', 'unban_user', 'softban']).order('created_at', { ascending: false }).limit(limit);
      if (!data?.length) return i.editReply({ embeds: [base().setDescription('No ban actions logged yet.')] });

      const ACTION_EMOJI = { ban_user: '🔨', unban_user: '✅', softban: '⏱️' };
      const lines = data.map(e => {
        const detail = e.details ? `@${e.details.username ?? '?'}${e.details.reason ? ` — ${e.details.reason}` : ''}` : '—';
        return `> ${ACTION_EMOJI[e.action] ?? '•'} **${e.action}** — ${detail} *(${timeAgo(e.created_at)})*`;
      }).join('\n');

      const embed = base()
        .setTitle(`📋 Ban Log (last ${data.length})`)
        .setDescription(lines);
      await i.editReply({ embeds: [embed] });
    },
  },

  {
    data: new SlashCommandBuilder()
      .setName('suspicious').setDefaultMemberPermissions(0)
      .setDescription('Find users with unusual execution patterns [Admin only]')
      .addIntegerOption(o => o.setName('threshold').setDescription('Min executions to flag (default 500)').setRequired(false).setMinValue(1)),
    async execute(i) {
      if (!isAdmin(i.user.id)) return i.reply({ embeds: [err('Admin only.')], ephemeral: true });
      await i.deferReply({ ephemeral: true });
      const threshold = i.options.getInteger('threshold') ?? 500;
      const since1h   = new Date(Date.now() - 3600000).toISOString();

      const { data } = await supabase
        .from('unique_users')
        .select('roblox_user_id,username,execution_count,last_seen,first_seen')
        .gte('last_seen', since1h)
        .gte('execution_count', threshold)
        .order('execution_count', { ascending: false })
        .limit(15);

      if (!data?.length) return i.editReply({ embeds: [base(COLORS.success).setDescription(`✅ No users found with ${fmt(threshold)}+ executions in the last hour.`)] });

      const lines = data.map(u => {
        const sessionMs = new Date(u.last_seen).getTime() - new Date(u.first_seen).getTime();
        const sessionMin = Math.max(1, Math.round(sessionMs / 60000));
        const rate = Math.round(u.execution_count / sessionMin);
        return `> ⚠️ **@${u.username}** — \`${fmt(u.execution_count)} execs\` · ~\`${rate}/min\` · last \`${timeAgo(u.last_seen)}\``;
      }).join('\n');

      const embed = base(COLORS.danger)
        .setTitle(`🚨 Suspicious Users (${data.length} flagged)`)
        .setDescription(lines)
        .setFooter({ text: `Threshold: ${fmt(threshold)}+ execs · active last 1h` });
      await i.editReply({ embeds: [embed] });
    },
  },

  {
    data: new SlashCommandBuilder()
      .setName('help')
      .setDescription('List all available commands'),
    async execute(i) {
      const admin = ADMIN_IDS.includes(i.user.id);
      const embed = base()
        .setTitle('📖 vhxLUA Bot Commands')
        .addFields(
          {
            name: '📊 Public',
            value: [
              '`/stats` — overall dashboard stats',
              '`/game [name]` — stats for a specific game',
              '`/whois [username]` — look up user by Roblox username',
              '`/changelog` — latest changelog entries',
              '`/ask [question]` — ask the AI anything',
              '`/help` — show this message',
            ].join('\n'),
          },
          ...(admin ? [{
            name: '🔒 Admin',
            value: [
              '`/user [token]` — look up user by token',
              '`/ban [username] [reason]` — ban a user',
              '`/unban [username]` — unban a user',
              '`/bans` — list all banned users',
              '`/softban [username] [duration] [unit]` — temp ban with auto-unban',
              '`/banlog` — ban audit trail',
              '`/suspicious [threshold]` — flag unusual execution patterns',
              '`/tokens` — list all verified tokens',
              '`/addchangelog [game] [type] [title]` — add changelog entry',
            ].join('\n'),
          }] : []),
        );
      await i.reply({ embeds: [embed], ephemeral: true });
    },
  },

  {
    data: new SlashCommandBuilder()
      .setName('ask')
      .setDescription('Ask the AI anything')
      .addStringOption(o => o.setName('question').setDescription('Your question').setRequired(true)),
    async execute(i) {
      await i.deferReply();
      const question = i.options.getString('question');
      const apiKey = process.env.GEMINI_API_KEY;
      if (!apiKey) return i.editReply({ embeds: [err('Gemini API key not configured.')] });
      try {
        const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{ parts: [{ text: `You are a helpful assistant for vhxLUA, a Roblox script hub. Answer concisely.\n\n${question}` }] }],
          }),
        });
        const json = await res.json();
        const answer = json?.candidates?.[0]?.content?.parts?.[0]?.text ?? 'No response.';
        const truncated = answer.length > 3900 ? answer.slice(0, 3900) + '...' : answer;
        const embed = base()
          .setTitle('🤖 AI Answer')
          .setDescription(`> **${question}**\n\n${truncated}`);
        await i.editReply({ embeds: [embed] });
      } catch {
        await i.editReply({ embeds: [err('Failed to get a response from Gemini.')] });
      }
    },
  },

];
