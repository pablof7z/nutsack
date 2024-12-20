import { Command } from 'commander';
import inquirer from 'inquirer';
import { readNsecFromFile, handleNsecCommand } from './commands/nsec';
import { normalizeRelayUrl } from './utils/url';
import { initNdk, ndk } from './lib/ndk';
import { activeWallet, initWallet } from './lib/wallet';
import { createWallet } from './commands/wallet/create';
import { setNutzapWallet } from './commands/wallet/set-nutzap-wallet.ts';
import { listWallets } from './commands/wallet/list.ts';
import { depositToWallet } from './commands/wallet/deposit.ts';
import { listTokens } from './commands/wallet/tokens';
import { pay } from './commands/wallet/pay';
import { condom } from './commands/condom/index.ts';
import { NDKCashuWallet } from '@nostr-dev-kit/ndk-wallet';
import { routeMessages } from './commands/route-messages.ts';
import chalk from 'chalk';
import { NDKEvent, NDKSubscription, NostrEvent } from '@nostr-dev-kit/ndk';
import { sweepNutzaps } from './commands/sweep-nutzaps.ts';
import { destroyAllProofs } from './commands/destroy-all.ts';

const program = new Command();
let loginPayload: string | null = null;
let relays: string[] = [];

program
  .version('1.0.0')
  .description('Your application description')
  .option('--bunker <bunker-uri>', 'Provide a bunker URI', (uri) => {
    loginPayload = uri;
  })
  .option('--nsec <nsec>', 'Provide an NSEC key', (nsec) => {
    loginPayload = nsec;
  })
  .option('-r, --relay <url>', 'Add a relay URL', (url, urls) => {
    urls.push(normalizeRelayUrl(url));
    return urls;
  }, []);

// Add the deposit command
program
  .command('deposit')
  .description('Deposit funds to a wallet')
  .option('--wallet <wallet-id>', 'Specify the wallet ID')
  .option('--mint <mint-url>', 'Specify the mint URL')
  .option('--amount <amount>', 'Specify the amount to deposit')
  .option('--unit <unit>', 'Specify the unit of the deposit')
  .action(async (options) => {
    await ensureNsec();
    await initNdk(relays, loginPayload!);
    await initWallet();
    await depositToWallet(options.mint, options.amount, options.unit);
  });

// Add the create wallet command
program
  .command('create-wallet')
  .description('Create a new wallet with specified options')
  .option('--name <name>', 'Specify the wallet name')
  .option('--mint <url>', 'Add a mint URL (can be used multiple times)', (url, urls) => {
    urls.push(normalizeRelayUrl(url));
    return urls;
  }, [])
  .option('--unit <unit>', 'Specify the default unit for the wallet')
  .action(async (options) => {
    await ensureNsec();
    await initNdk(relays, loginPayload!);
    await initWallet();
    await createWallet(options.name, options.mint, options.unit);
  });

program
  .command('sweep-nutzaps')
  .description('Sweep all nutzaps')
  .action(async () => {
    await ensureNsec();
    await initNdk(relays, loginPayload!);
    await initWallet();
    await sweepNutzaps();
  });

// Update the pay command
program
  .command('pay <payload>')
  .description('Make a payment from your wallet (BOLT11 invoice or NIP-05)')
  .option('--amount <amount>', 'Specify the amount to pay')
  .action(async (payload, options) => {
    await ensureNsec();
    await initNdk(relays, loginPayload!);
    await initWallet();
    await pay(payload, options.amount);
  });

// Add your commands here

program
  .command('cli')
  .description('Start the interactive CLI mode')
  .action(startInteractiveMode);

program
  .command('ls')
  .description('List wallets')
  .option('-l', 'Show all details')
  .action(async (options) => {
    await ensureNsec();
    await initNdk(relays, loginPayload!);
    await initWallet();
    await listWallets(options.l);

    let events = new Set();
    let events2 = new Set();

    let sub2: NDKSubscription;
    let countAfterEose = -1;

    ndk.debug.enabled = true;
    
    for (let i = 0; i < 50; i++) {
        console.log(i);
        ndk.subscribe([ { kinds: [999], limit: i+1 }, ], { groupable: true }, undefined, true)
    }
    
    // process.exit(0);
  });

// Add the ls-tokens command
program
  .command('ls-tokens')
  .description('List all tokens in the wallet')
  .option('-v, --verbose', 'Show verbose output')
  .action(async (options) => {
    await ensureNsec();
    await initNdk(relays, loginPayload!);
    await initWallet();
    await listTokens(options.verbose);
    process.exit(0);
  });

program
  .command('publish <message>')
  .description('Publish a message')
  .action(async (message) => {
    await ensureNsec();
    await initNdk(relays, loginPayload!);
    await initWallet();

    const event = new NDKEvent(ndk, {
      kind: 1,
      content: message,
    } as NostrEvent);
    await event.sign();
    await event.publish();

    console.log('published https://njump.me/' + event.encode());
    
    // await condom(message);
  });

program.command("route")
  .description("Route messages")
  .option("--onion-relay <url>", "Relay where to listen for incoming onion-routed messages", (url, urls) => {
    urls.push(url);
    return urls;
  }, [])
  .option("--fee <amount>", "Fee in sats for the relay to relay the message")
  .action(async (opts) => {
    await ensureNsec();
    await initNdk(relays, loginPayload!);
    await initWallet();
    routeMessages(opts)
  });

program
  .command('validate')
  .description('Validate all proofs')
  .action(async () => {
    await ensureNsec();
    await initNdk(relays, loginPayload!);
    await initWallet();

    await new Promise(resolve => setTimeout(resolve, 1000));

    if (!activeWallet) {
      console.error('No wallet found. Please create a wallet first.');
      process.exit(1);
    }
    const res = await activeWallet.checkProofs();
    console.log(res);
  });

program
  .command('token <amount> <unit>')
  .description('Create a new token')
  .action(async (amount, unit) => {
    await ensureNsec();
    await initNdk(relays, loginPayload!);
    await initWallet();

    if (!activeWallet) {
      console.error('No wallet found. Please create a wallet first.');
      process.exit(1);
    }

    const mintTokens = activeWallet.mintTokens;
    for (const [mint, tokens] of Object.entries(mintTokens)) {
      console.log(mint);

      for (const token of tokens) {
        console.log(token.proofs.map(p => p.amount));
      }
    }

    const proofs = await activeWallet.mintNuts([1, 1], 'sat');
    console.log('minted proofs', proofs);
    
    // const token = await wallet.mint(amount, unit);
    
    // console.log('Token minted:', token);
  });

async function promptForNsec(): Promise<string> {
  const { nsec } = await inquirer.prompt([
    {
      type: 'password',
      name: 'nsec',
      message: 'Enter your NSEC key:',
      validate: (input) => input.length > 0 || 'NSEC key cannot be empty',
    },
  ]);
  return nsec;
}

async function ensureNsec() {
  if (!loginPayload) {
    loginPayload = await readNsecFromFile();
    if (!loginPayload) {
      loginPayload = await promptForNsec();
      await handleNsecCommand(loginPayload);
    }
  }
}

async function promptForCommand() {
  const user = ndk!.activeUser?.npub;
  const { command } = await inquirer.prompt([
    {
      type: 'input',
      name: 'command',
      message: `${chalk.bgGray('['+user?.substring(0,10)+']')} 🥜 >`,
    },
  ]);

  if (command.toLowerCase() === 'help') {
    console.log('Available commands:');
    console.log('  help                - Show this help message');
    console.log('  create              - Create a new wallet');
    console.log('  publish [message]   - Publish a new note with an onion-routed message');
    console.log('  set-nutzap-wallet [naddr...]   - Set the NIP-60 wallet that should receive nutzaps');
    console.log('  ls [-l]             - List wallets (use -l to show all details)');
    console.log('  deposit             - Deposit funds to a wallet');
    console.log('  destroy             - Destroy all tokens in the wallet');
    console.log('  sweep-nutzaps       - Sweep all nutzaps');
    console.log('  me                  - Show your npub');
    console.log('  exit                - Quit the application');
    console.log('  create-wallet       - Create a new wallet with specified options');
    console.log('  ls-tokens [-v]      - List all tokens in the wallet (use -v for verbose output)');
    console.log('  pay <payload>       - Make a payment (BOLT11 invoice or NIP-05)');
    // Add more commands here as they are implemented
  } else if (command.toLowerCase() === 'deposit') {
    await depositToWallet();
  } else if (command.toLowerCase().startsWith('publish ')) {
    const message = command.replace(/^publish /, '').trim();
    await condom(message);
    await new Promise(resolve => setTimeout(resolve, 1000));
  } else if (command.toLowerCase() === 'destroy') {
    await destroyAllProofs();
  } else if (command.toLowerCase() === 'me') {
    console.log(ndk!.activeUser?.npub);
  } else if (command.toLowerCase() === 'sweep-nutzaps') {
    await sweepNutzaps();
  } else if (command.toLowerCase().startsWith('route')) {
    const args = command.split(' ');
    const opts = {
      onionRelay: [],
      fee: 0,
    } as { onionRelay: string[], fee: number };
    for (let i = 1; i < args.length; i++) {
      if (args[i].startsWith('--fee')) {
        opts.fee = parseInt(args[i + 1]);
        args.splice(i, 2);
        break;
      } else {
        opts.onionRelay.push(args[i]);
      }
    }
    await routeMessages(opts);
  } else if (command.toLowerCase().startsWith('deposit ')) {
    const args = command.split(' ');
    if (args.length > 4) {
      console.log('Usage: deposit [mint-url] [amount] [unit]');
    } else {
      const [, mintUrl, amount, unit] = args;
      await depositToWallet(mintUrl, amount, unit);
    }
  } else if (command.toLowerCase().startsWith('create')) {
    const createdWallet = await createWallet();
    if (createdWallet) {
      const { setAsNutzap } = await inquirer.prompt([
        {
          type: 'confirm',
          name: 'setAsNutzap',
          message: 'Do you want to set this wallet as the Nutzap wallet?',
          default: false,
        },
      ]);
      if (setAsNutzap) {
        await setNutzapWallet(createdWallet.event.encode());
      }
    }
  } else if (command.toLowerCase().startsWith('set-nutzap-wallet')) {
    const naddr = command.split(' ')[1];
    await setNutzapWallet(naddr);
  } else if (/^ls(\s|$)/.test(command.toLowerCase())) {
    const args = command.split(' ');
    const showAll = args.includes('-l');
    await listWallets(showAll);
  } else if (command.toLowerCase().startsWith('ls-tokens')) {
    const args = command.split(' ');
    const verbose = args.includes('-v');
    await listTokens(verbose);
  } else if (command.toLowerCase().startsWith('pay ')) {
    const payload = command.split(' ')[1];
    const { amount } = await inquirer.prompt([
      {
        type: 'input',
        name: 'amount',
        message: 'Enter the amount to pay (optional):',
      },
    ]);
    await pay(payload, parseInt(amount));
  } else {
    try {
      await program.parseAsync(command.split(' '), { from: 'user' });
    } catch (error) {
      console.error('Error:', error.message);
    }
  }

  // Continue prompting
  await promptForCommand();
}

async function startInteractiveMode() {
  console.log('Welcome to the interactive CLI. Type "help" for available commands or "exit" to quit.');
  await ensureNsec();
  await initNdk(relays, loginPayload!);
  await initWallet();
  await promptForCommand();
}

async function main() {
  program.parse(process.argv);
  const options = program.opts();

  if (options.nsec) loginPayload = options.nsec;
  if (options.bunker) loginPayload = options.bunker;
  
  if (options.relay) {
    relays = options.relay;
  }

  const command = program.args[0];
}

main().catch(console.error);
