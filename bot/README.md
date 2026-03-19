# vhxbot

Discord bot for vhxLUA Hub — fetches data from Supabase.

## Setup

1. Clone the repo
2. `npm install`
3. Copy `.env.example` to `.env` and fill in your values:
   - `DISCORD_TOKEN` — bot token from Discord Developer Portal
   - `CLIENT_ID` — application ID from Discord Developer Portal
   - `GUILD_ID` — your Discord server ID
   - `SUPABASE_URL` / `SUPABASE_KEY` — already filled
   - `ADMIN_USER_IDS` — your Discord user ID (comma-separated for multiple)

4. Register commands: `npm run deploy`
5. Start the bot: `npm start`

## Commands

| Command | Description | Admin only |
|---|---|---|
| `/stats` | Overall dashboard stats | |
| `/game [name]` | Stats for a specific game | |
| `/user [token]` | Look up user by token | |
| `/whois [username]` | Look up user by Roblox username | |
| `/changelog` | Show latest changelog entries | |
| `/ban [username] [reason]` | Ban a user | ✅ |
| `/unban [username]` | Unban a user | ✅ |
| `/bans` | List all banned users | ✅ |
| `/tokens` | List all verified tokens | ✅ |
| `/addchangelog` | Add a changelog entry | ✅ |

## Hosting

Works on any Node.js 18+ host — Railway, Fly.io, or a VPS.
