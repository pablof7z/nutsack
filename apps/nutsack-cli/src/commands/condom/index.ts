import { Hexpubkey, NDKEvent, NDKEventId, NDKPrivateKeySigner, NDKRelay, NDKRelaySet, NDKUserProfile, NostrEvent } from "@nostr-dev-kit/ndk";
import chalk from "chalk";
import inquirer from "inquirer";
import { ndk } from "../../lib/ndk";
import { CashuWallet, getEncodedToken, Proof } from "@cashu/cashu-ts";
import { walletService } from "../../lib/wallet";
import { NDKCashuWallet } from "@nostr-dev-kit/ndk-wallet";

const profiles: Record<string, string> = {};

async function getCondoms() {
    const condoms = await ndk.fetchEvents({
        kinds: [26969]
    });

    const uniqueCondoms = new Map();
    condoms.forEach(condom => {
        if (!uniqueCondoms.has(condom.pubkey)) {
            uniqueCondoms.set(condom.pubkey, condom);
        }
    });

    return Array.from(uniqueCondoms.values());
}

function mapCondomToChoices(condom: NDKEvent) {
    const relays = condom.getMatchingTags('relay').map(r => r[1]);
    // if (!relays.length) return undefined;

    const fee = condom.getMatchingTags('fee')[0];

    let name = `${condom.author.npub.slice(0,10)}} (Relays: ${relays.join(', ')})`;
    if (fee) {
        name += chalk.white(` (Fee: ${fee[1]} ${fee[2]??'sat'})`);
    }

    return { 
        name, 
        value: { pubkey: condom.pubkey, relays: relays, fee: fee?parseInt(fee[1]):undefined }
    };
}

async function selectCondoms(condoms: NDKEvent[]) {
    const { condoms: selectedCondoms } = await inquirer.prompt([
        {
            type: 'checkbox',
            name: 'condoms',
            message: 'Select condoms',
            choices: await Promise.all(condoms.map(mapCondomToChoices).filter(c => c !== undefined))
        }
    ])
    return selectedCondoms;
}

export async function condom(content: string) {
    const condoms = await getCondoms();

    const selectedCondoms = await selectCondoms(condoms);
    return new Promise<void>((resolve, reject) => {
        constructMessage(content, selectedCondoms, resolve);
    });
}

async function getProofs(condoms: Hop[]): Promise<(Proof|undefined)[]> {
    const fees: number[] = [];
    for (const condom of condoms) {
        fees.push(condom.fee ?? 0);
    }

    const wallet = walletService.defaultWallet as NDKCashuWallet;

    if (!wallet) {
        console.error('No wallet found. Please create a wallet first.');
        process.exit(1);
    }

    const nutsToMint = fees.filter(f => f > 0);
    if (nutsToMint.length === 0) {
        return [];
    }

    const nuts = await wallet.mintNuts(nutsToMint, 'sat');

    if (nuts && nuts.length > 0) {
        console.log(chalk.blue('Minted', nuts.length, 'nuts'));
    }

    if (!nuts) {
        console.error('Failed to mint nuts');
        process.exit(1);
    }

    // return the same number of proofs as condoms
    // the proofs are in the same order as the condoms
    // the proofs that are zero fee return an empty slot in the array
    const ret: (Proof|undefined)[] = [];
    for (let i = 0; i < condoms.length; i++) {
        if (fees[i] === 0) {
            ret.push(undefined);
        } else {
            ret.push(nuts.shift());
        }
    }
    return ret;
}

async function constructMessage(content: string, condoms: Hop[], resolve: () => void) {
    const targetMessage = new NDKEvent(ndk, { kind: 1, content });
    await targetMessage.sign();

    const hops: { eventId: NDKEventId, relays: string[] }[] = [];

    let relaySet: NDKRelaySet | undefined;
    let outerWrapEvent: NDKEvent | undefined = targetMessage;

    const proofs = await getProofs(condoms);

    // walk condoms backwards
    for (let i = condoms.length - 1; i >= 0; i--) {
        const condom = condoms[i];
        condom.proof = proofs[i];
        let nextHop = condoms[i + 1];

        // if we don't have a next hop, we just fill in the relays
        if (!nextHop) {
            nextHop = {
                relays: ndk.explicitRelayUrls
            }
        }

        console.log({ condom, nextHop, i });

        outerWrapEvent = await createWrap(
            condom,
            nextHop,
            JSON.stringify(outerWrapEvent.rawEvent())
        );

        hops.push({ eventId: outerWrapEvent.id, relays: condom.relays });
    }

    let startTime = Date.now();

    // push the targetMessage as the last hop
    hops.push({ eventId: targetMessage.id, relays: ndk.explicitRelayUrls });

    for (let index = 0; index < hops.length; index++) {
        const hop = hops[index];
        relaySet = NDKRelaySet.fromRelayUrls(hop.relays, ndk);
        const sub = ndk.subscribe({ ids: [hop.eventId] }, { groupable: false, skipOptimisticPublishEvent: true }, relaySet);
        // console.log(chalk.green('Subscribed to ', Array.from(r).map(r => r.url).join(', ')), 'with event', hop.eventId);
        sub.on('event', (event, relay: NDKRelay | undefined) => {
            const t = Date.now();
            const time = t - startTime;
            startTime = t;
            let relayUrl = relay?.url;

            relayUrl ??= condoms[index].relays[0];
            
            const fixedLengthUrl = relayUrl.substring(0,30).padEnd(30, ' ');
            console.log(`${chalk.bgGray(event.id.substring(0,6))} ${chalk.green(fixedLengthUrl)} ${chalk.yellow(time+"ms")}`);

            if (event.id === targetMessage.id) {
                console.log(chalk.bgMagenta('Onion-routed message published!'));
                console.log(chalk.white("https://nostr.at/"+targetMessage.encode()));

                resolve();
            }
        });
    }

    relaySet = NDKRelaySet.fromRelayUrls(condoms[0].relays, ndk);
    startTime = Date.now();

    const r = await outerWrapEvent.publish(relaySet);
    // console.log('constructed full wrap', outerWrapEvent.rawEvent());
    // console.log('published', Array.from(r).map(r => r.url));
}

type Hop = {
    pubkey?: Hexpubkey;
    proof?: Proof;
    relays: string[];
    fee?: number;
}

type Payload = {
    relays: string[];
    pubkey?: Hexpubkey;
    proof?: Proof;
    mint?: string;
    unit?: string;
    payload: string;
}

/**
 * Create a wrap around the payload for the next hop    
 * @param hop Details about the hop we are wrapping for
 * @param nextHop Details about the next hop the current hop should reach out to
 * @param payload The payload to send to the next hop
 * @returns 
 */
async function createWrap(hop: Hop, nextHop: Hop, payload: string): Promise<NDKEvent> {
    // create the envelope the current hop will look at, it tells it to which relays
    // it should publish the payload
    const nextHopPayload: Payload = {
        relays: nextHop.relays,
        payload
    }

    if (nextHop.pubkey) {
        nextHopPayload.pubkey = nextHop.pubkey;
    }

    if (hop.proof) {
        nextHopPayload.proof = hop.proof;
        nextHopPayload.mint = "https://mint.coinos.io";
        nextHopPayload.unit = "sat";
    }

    const signer = NDKPrivateKeySigner.generate();

    // encrypt the payload to the pubkey of the current hop
    const event = new NDKEvent(ndk, {
        kind: 20690,
        content: JSON.stringify(nextHopPayload),
        tags: [
            ["p", hop.pubkey]
        ]
    } as NostrEvent);

    const hopUser = await ndk.getUser({pubkey: hop.pubkey});

    await event.encrypt(hopUser, signer, 'nip44');
    await event.sign(signer);

    return event;
}
