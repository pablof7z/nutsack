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
    await ensureRelays();
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
    await ensureRelays();
    await initNdk(relays, currentNsec!);
    await initWallet();
    await createWallet(options.name, options.mint, options.unit);
  });

// Add your commands here

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

async function promptForRelays(): Promise<void> {
  while (true) {
    const { relay } = await inquirer.prompt([
      {
        type: 'input',
        name: 'relay',
        message: 'Enter a relay URL (or press enter to finish):',
      },
    ]);

    if (!relay) break;
    relays.push(normalizeRelayUrl(relay));
  }
}

async function ensureRelays() {
  if (relays.length === 0) {
    console.log('No relays provided. Please enter at least one relay.');
    await promptForRelays();
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
    // Add more commands here as they are implemented
  } else if (command.toLowerCase() === 'create') {
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
    // ... existing set-nutzap-wallet code ...
  } else if (command.toLowerCase().startsWith('ls')) {
    const args = command.split(' ');
    const showEll = args.includes('-l');
    await listWallets(showEll);
  } else if (command.toLowerCase() === 'deposit') {
    await depositToWallet();
  } else if (command.toLowerCase() === 'exit') {
    console.log('Goodbye!');
    process.exit(0);
  } else if (command.toLowerCase() === 'create-wallet') {
    const { name, mints, unit } = await inquirer.prompt([
      {
        type: 'input',
        name: 'name',
        message: 'Enter the wallet name:',
      },
      {
        type: 'input',
        name: 'mints',
        message: 'Enter mint URLs (comma-separated):',
      },
      {
        type: 'input',
        name: 'unit',
        message: 'Enter the default unit:',
      },
    ]);
    const mintUrls = mints.split(',').map(url => url.trim());
    await createWalletWithOptions(name, mintUrls, unit);
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

async function main() {
  program.parse(process.argv);
  const options = program.opts();

  if (options.nsec) {
    currentNsec = options.nsec;
    await handleNsecCommand(currentNsec);
  }

  if (options.relay) {
    relays = options.relay;
    console.log('Relays:', relays);
  }

  // Check if a command was provided
  const command = program.args[0];

  if (command) {
    // A command was provided, execute it directly
    await program.parseAsync(process.argv);
  } else if (process.argv.length === 2 || options.nsec || options.relay) {
    // No command provided, enter interactive mode
    console.log('Welcome to the interactive CLI. Type "exit" to quit.');
    await ensureNsec();
    await ensureRelays();

    await initNdk(relays, currentNsec!);
    await initWallet();

    await promptForCommand();
  }
}

main().catch(console.error);
