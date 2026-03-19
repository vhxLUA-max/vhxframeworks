import { Client, GatewayIntentBits, Collection } from 'discord.js';
import { commands } from './src/commands/index.js';
import { err } from './src/embeds.js';
import 'dotenv/config';

const client = new Client({ intents: [GatewayIntentBits.Guilds] });
const map = new Collection();

for (const cmd of commands) map.set(cmd.data.name, cmd);

client.once('ready', () => {
  console.log(`✅ Logged in as ${client.user.tag}`);
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
