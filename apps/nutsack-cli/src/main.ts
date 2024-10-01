import { Command } from 'commander';
import inquirer from 'inquirer';
import { readNsecFromFile, handleNsecCommand } from './commands/nsec';
import { normalizeRelayUrl } from './utils/url';
import { initNdk, ndk } from './lib/ndk';
import { initWallet } from './lib/wallet';
import { createWallet } from './commands/wallet/create';
import { setNutzapWallet } from './commands/wallet/set-nutzap-wallet.ts';
import { listWallets } from './commands/wallet/list.ts';
import { depositToWallet } from './commands/wallet/deposit.ts';
import { listTokens } from './commands/wallet/tokens';
import { pay } from './commands/wallet/pay';

const program = new Command();
let currentNsec: string | null = null;
let relays: string[] = [];

program
  .version('1.0.0')
  .description('Your application description')
  .option('--nsec <nsec>', 'Provide an NSEC key')
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
    await initNdk(relays, currentNsec!);
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
    await initNdk(relays, currentNsec!);
    await initWallet();
    await createWallet(options.name, options.mint, options.unit);
  });

// Update the pay command
program
  .command('pay <payload>')
  .description('Make a payment from your wallet (BOLT11 invoice or NIP-05)')
  .option('--wallet <wallet-id>', 'Specify the wallet ID to pay from')
  .action(async (payload, options) => {
    await ensureNsec();
    await initNdk(relays, currentNsec!);
    await initWallet();
    await pay(payload, options.wallet);
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
    await initNdk(relays, currentNsec!);
    await initWallet();
    await listWallets(options.l);
    process.exit(0);
  });

// Add the ls-tokens command
program
  .command('ls-tokens')
  .description('List all tokens in the wallet')
  .option('-v, --verbose', 'Show verbose output')
  .action(async (options) => {
    await ensureNsec();
    await initNdk(relays, currentNsec!);
    await initWallet();
    await listTokens(options.verbose);
    process.exit(0);
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
  if (!currentNsec) {
    currentNsec = await readNsecFromFile();
    if (!currentNsec) {
      currentNsec = await promptForNsec();
      await handleNsecCommand(currentNsec);
    }
  }
}

async function promptForCommand() {
  const { command } = await inquirer.prompt([
    {
      type: 'input',
      name: 'command',
      message: 'Enter a command (or "help" for available commands, "exit" to quit):',
    },
  ]);

  if (command.toLowerCase() === 'help') {
    console.log('Available commands:');
    console.log('  help                - Show this help message');
    console.log('  create              - Create a new wallet');
    console.log('  set-nutzap-wallet [naddr...]   - Set the NIP-60 wallet that should receive nutzaps');
    console.log('  ls [-l]             - List wallets (use -l to show all details)');
    console.log('  deposit             - Deposit funds to a wallet');
    console.log('  exit                - Quit the application');
    console.log('  create-wallet       - Create a new wallet with specified options');
    console.log('  ls-tokens [-v]      - List all tokens in the wallet (use -v for verbose output)');
    console.log('  pay <payload>       - Make a payment (BOLT11 invoice or NIP-05)');
    // Add more commands here as they are implemented
  } else if (command.toLowerCase() === 'deposit') {
    await depositToWallet();
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
    const { wallet } = await inquirer.prompt([
      {
        type: 'input',
        name: 'wallet',
        message: 'Enter the wallet ID to pay from (optional):',
      },
    ]);
    await pay(payload, wallet);
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
  await initNdk(relays, currentNsec!);
  await initWallet();
  await promptForCommand();
}

async function main() {
  program.parse(process.argv);
  const options = program.opts();

  if (options.nsec) {
    currentNsec = options.nsec;
    await handleNsecCommand(currentNsec);
  }

  if (options.relay) {
    relays = options.relay;
  }

  const command = program.args[0];
}

main().catch(console.error);
