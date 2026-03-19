import { Client, GatewayIntentBits, Collection } from 'discord.js';
import { commands } from './src/commands/index.js';
import { err } from './src/embeds.js';
import { supabase } from './src/supabase.js';
import 'dotenv/config';

const client = new Client({ intents: [GatewayIntentBits.Guilds] });
const map = new Collection();

for (const cmd of commands) map.set(cmd.data.name, cmd);

const processAutoUnbans = async () => {
  const { data } = await supabase.from('banned_users').select('id,username').lte('unban_at', new Date().toISOString()).not('unban_at', 'is', null);
  if (!data?.length) return;
  for (const row of data) {
    await supabase.from('banned_users').delete().eq('id', row.id);
    console.log(`Auto-unbanned @${row.username}`);
  }
};

client.once('ready', () => {
  console.log(`✅ Logged in as ${client.user.tag}`);
  processAutoUnbans();
  setInterval(processAutoUnbans, 60000);
});

client.on('interactionCreate', async interaction => {
  if (!interaction.isChatInputCommand()) return;
  const cmd = map.get(interaction.commandName);
  if (!cmd) return;
  try {
    await cmd.execute(interaction);
  } catch (e) {
    console.error(e);
    const payload = { embeds: [err('Something went wrong.')], ephemeral: true };
    if (interaction.deferred || interaction.replied) interaction.editReply(payload);
    else interaction.reply(payload);
  }
});

client.login(process.env.DISCORD_TOKEN);
