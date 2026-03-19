import { REST, Routes } from 'discord.js';
import { commands } from './src/commands/index.js';
import 'dotenv/config';

const rest = new REST().setToken(process.env.DISCORD_TOKEN);

const body = commands.map(c => c.data.toJSON());

await rest.put(
  Routes.applicationGuildCommands(process.env.CLIENT_ID, process.env.GUILD_ID),
  { body }
);

console.log(`✅ Registered ${body.length} commands to guild ${process.env.GUILD_ID}`);
