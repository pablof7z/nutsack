import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { ActivityIndicator } from "./nativewindui/ActivityIndicator";
import { Button, ButtonState } from "./nativewindui/Button";
import { Text } from "./nativewindui/Text";
import { NDKCashuMintList, NDKEvent, NDKKind, NDKSubscription, useNDK, useNDKCacheInitialized, useNDKCurrentUser, useNDKSession, useNDKSessionEventKind, useNDKSessionEvents, useNDKWallet, useSubscribe } from "@nostr-dev-kit/ndk-mobile";
import { View, Image, TextInput, TouchableOpacity, Touchable, TouchableWithoutFeedback } from "react-native";
import LoginComponent from "./login";
import { ArrowRight, Bolt } from "lucide-react-native";
import { CashuMint, CashuWallet } from "@cashu/cashu-ts";
import { ProgressIndicator } from '~/components/nativewindui/ProgressIndicator';
import { NDKCashuWallet } from "@nostr-dev-kit/ndk-wallet";
import { ScrollView } from "react-native";
import { Checkbox } from "./nativewindui/Checkbox";
import { useAtomValue } from "jotai";
import { appReadyAtom } from "@/atoms/app";

function Container({ skipImage, children }: { skipImage?: boolean, children?: React.ReactNode }) {
    const currentUser = useNDKCurrentUser();
    const { logout } = useNDK();
    const splashImage = require('../assets/splash.png');

    return (
        <View className="flex bg-black flex-col relative h-screen w-screen items-stretch">
            {!skipImage && <Image source={splashImage} className="h-screen w-screen absolute top-0 left-0" />}

            <View className="flex flex-col absolute bottom-10 left-10 z-10 right-10 items-center">
                {skipImage && (
                    <View className="flex-col items-center justify-center flex-1 w-full mb-10">
                        <Bolt size={128} color="white" />
                    </View>
                )}
                
                {children}
                
                {!!currentUser && (
                    <Button variant="plain" onPress={() => {
                        logout();
                    }}>
                        <Text className="text-white font-semibold py-3">
                            Logout
                        </Text>
                    </Button>
                )}
            </View>
        </View>
    );
}

// The app is initializing
function Initializing() {
    return (
        <Container>
            <ActivityIndicator className="mt-4" color="white" />
        </Container>
    );
}

// App finished initializing, but the user is not logged in
function GetStarted({ onReady }: { onReady: () => void }) {
    return (
        <Container>
            <Button variant="accent" className="mt-4" onPress={onReady}>
                <Text className="text-white font-semibold py-3 px-20">
                    Get Started
                </Text>
            </Button>
        </Container>
    )
}

function Welcome({ onReady }: { onReady: () => void }) {
    const [ step, setStep ] = useState(0);

    const step1 = (
        <>
            <Text className="text-white text-2xl font-black pt-3 text-left">
                    What is Honeypot?
            </Text>
            
            <Text className="text-white text-lg font-bold -mt-2 text-left">
                    A NIP 60 client.
                </Text>

                <Text className="text-white text-lg font-regular py-1 text-left">
                    In other words, a nostr client that
                    interfaces with your nostr-native ecash.
                </Text>

                <Text className="text-white text-lg font-regular py-1 text-left">
                    You no longer need to do pair with an external
                    wallet; your wallet is IN the relay.
                </Text>
            
                <Text className="text-white text-lg font-regular py-1 text-left">
                    Much like money in your pocket, every time you walk into a store you don't
                    have to do a magical dance to have access to those notes.
                </Text>
            
                <Text className="text-white text-lg font-bold py-1 text-left">
                    A NIP-60 wallet is cash that follows you around on the internet.
                </Text>
        </>
    )

    const step2 = (
        <>
            <Text className="text-white text-2xl font-black pt-3 text-left">
                Nutzaps
            </Text>

            <Text className="text-white text-lg font-semibold py-1 text-left">
                Honeypot also supports NIP-61, Nutzaps. A way to send verifiable, faster, and more reliable zaps.
            </Text>

            <Text className="text-white text-lg font-semibold py-1 text-left">
                More importantly, nutzaps DON'T require setting up an external wallet;
            </Text>

            <Text className="text-white text-lg font-semibold py-1 text-left">
                New Nostr users can immediately receive zaps with no hassle; no more of the dreaded
                "hey, you don't have lightning, install X, Y or Z!"
            </Text>
        </>
    )

    const step3 = (
        <>
            <Text className="text-white text-2xl font-black pt-3 text-left">
                Cashu
            </Text>

            <Text className="text-white text-lg font-semibold py-1 text-left">
                Honeypot works with Cashu under the hood; the wallet balance is custody by the mints
                you select.
            </Text>

            <Text className="text-white text-lg font-semibold py-1 text-left">
                You can also add your own mints to the wallet.
            </Text>

            <Text className="text-white text-lg font-semibold py-1 text-left">
                Much like Wallet of Satoshi, and what 95% of nostr users use,
                cashu is custodial; the benefit, though, is that instead of keeping your whole
                balance in a single custodian, you can split it up across multiple mints.
            </Text>
        </>
    )

    const step4 = (
        <>
            <Text className="text-white text-2xl font-black pt-3 text-left">
                Experimental
            </Text>

            <Text className="text-white text-lg font-semibold py-1 text-left">
                Always keep in mind, this is extremely experimental, so don't
                load up big balances.
            </Text>

            <Text className="text-white text-lg font-semibold py-1 text-left">
                Bugs are to be expected.
            </Text>
        </>
    )

    const next = () => {
        if (step >= 3) {
            onReady();
        } else {
            setStep(step + 1);
        }
    }

    const [progress, setProgress] = useState(0);
    
    useEffect(() => {
        setProgress(((step + 1) / 4) * 100);
    }, [step]);
    
    return (
        <Container skipImage>
            <View className="flex-col items-start justify-start gap-4 w-full mb-[10vh]">
                {step === 0 && step1}
                {step === 1 && step2}
                {step === 2 && step3}
                {step === 3 && step4}
            </View>

            <ProgressIndicator value={progress} />

            <Button variant="accent" className="mt-4 !py-3 !px-20" onPress={next}>
                <Text className="text-white font-semibold">
                    Continue
                </Text>
                <ArrowRight size={20} color="white" />
            </Button>
        </Container>
    )
}

function Login() {
    return (
        <View className="bg-black items-center justify-center flex-col flex-1">
            <View className="flex-col items-center justify-center flex-1 w-full">
                <View className="flex-row items-center justify-center gap-4">
                    <Bolt size={48} color="white" />
                    <Text className="text-white text-2xl font-bold">
                        Honeypot
                    </Text>
                </View>
                <View className="w-full h-1/2 px-10">
                    <LoginComponent
                        textClassName="text-white"
                    />
                </View>
            </View>
        </View>
    )
}

function CheckingWallets() {
    return (
        <Container>
            <View className="flex-col items-center justify-center flex-1 w-full mb-10">
                <ActivityIndicator className="mt-4" color="white" />
                <Text className="text-white">Checking for wallets...</Text>
            </View>
        </Container>
    )
}

function ChooseWallet({ wallets, onChoose, onCreateNew }: { wallets: NDKEvent[], onChoose: (wallet: NDKEvent) => void, onCreateNew: () => void }) {
    return (
        <Container skipImage>
            <View className="flex-col items-center justify-center flex-1 w-full mb-10">
                <Text className="text-white text-2xl font-bold">
                    Choose one of your wallets
                </Text>
            </View>
            
            <View className="flex-col items-center justify-center flex-1 w-full mb-10">
                {wallets.map(wallet => (
                    <TouchableOpacity key={wallet.id} onPress={() => onChoose(wallet)}>
                        <View className="flex-row items-center justify-center gap-4">
                            <Text className="text-white font-mono">{wallet.dTag} ({wallet.getMatchingTags("mint").length} mints)</Text>
                        </View>
                    </TouchableOpacity>
                ))}
            </View>

            <Button variant="accent" className="mt-4 w-full" onPress={onCreateNew}>
                <Text className="text-white font-semibold">
                    Create a new wallet
                </Text>
            </Button>
        </Container>
    )
}

function CreateNewWallet({ proceedWithoutWallet }: { proceedWithoutWallet: () => void }) {
    const { ndk } = useNDK();
    const { setActiveWallet } = useNDKWallet();

    const [ knownMints, setKnownMints ] = useState(new Set<string>());
    const queryingMints = useRef(new Set<string>());
    const [ mints, setMints ] = useState(new Set<string>());
    const unqueriedMints = useRef(new Set<string>());

    const rejectedMints = useRef(new Set<string>());
    const fullUrl = useRef(new Map<string, string>());

    const sub = useRef<NDKSubscription | null>(null);

    const queryMint = (url: string, normalizedUrl: string) => {
        if (rejectedMints.current.has(normalizedUrl)) {
            return;
        }

        const mint = new CashuMint(url);
        const w = new CashuWallet(mint);
        w.createMintQuote(1000).then(info => {
            queryingMints.current.delete(normalizedUrl);
            if (info) {
                console.log('adding mint', url);
                mints.add(url);
                setMints(new Set(mints));
            } else {
                console.log('failed to query mint', url);
            }
        }).catch(e => {
            console.error('error querying mint', url, e);
            queryingMints.current.delete(normalizedUrl);
        });
    }

    const eventHandler = useCallback((event: NDKEvent) => {
        const url = event.tagValue('u');
        const normalizedUrl = new URL(url).hostname;

        if (rejectedMints.current.has(normalizedUrl)) return;
        if (knownMints.has(normalizedUrl)) return;

        setKnownMints(prev => new Set([...prev, normalizedUrl]));

        if (queryingMints.current.size > 10) {
            unqueriedMints.current.add(normalizedUrl);
            fullUrl.current.set(normalizedUrl, url);
        } else {
            queryingMints.current.add(normalizedUrl);
            queryMint(url, normalizedUrl);
        }
    }, [knownMints, mints]);

    if (!sub.current) {
        sub.current = ndk.subscribe([{ kinds: [38172 as NDKKind], limit: 300 }], { groupable: false, closeOnEose: true, subId: 'mints' }, undefined, false);
        sub.current.on('event', eventHandler);
        sub.current.start();
    }

    useEffect(() => {
        console.log('running effect', mints.size, unqueriedMints.current.size, queryingMints.current.size);
        if (mints.size <= 6 && queryingMints.current.size < 5) {
            // get 3 mints from unqueriedMints, query them, and remove them from unqueriedMints
            const mintsToQuery = Array.from(unqueriedMints.current).slice(0, 10);
            mintsToQuery.forEach(mint => {
                console.log('querying mint', mint);
                queryingMints.current.add(mint);
                const url = fullUrl.current.get(mint);
                if (url) {
                    queryMint(url, mint);
                }
                unqueriedMints.current.delete(mint);
            });
        }
    }, [mints, queryingMints]);
    
    const [ state, setState ] = useState<ButtonState>('idle');
    
    const createWallet = async () => {
        setState('loading');
        const relayUrls = ndk.pool.connectedRelays().map(r => r.url);
        const wallet = NDKCashuWallet.create(ndk, Array.from(mints), relayUrls);
        wallet.name = "My Wallet";
        await wallet.getP2pk();
        wallet.publish().then(() => {
            setState('success');

            if (nutzaps) {
                const mintList = new NDKCashuMintList(ndk);
                mintList.mints = wallet.mints;
                mintList.relays = wallet.relays;
                mintList.p2pk = wallet.p2pk;
                mintList.publish().then(() => {
                    console.log('calling setActiveWallet', wallet);
                    setActiveWallet(wallet);
                });
            } else {
                console.log('calling setActiveWallet no mint list', wallet);
                setActiveWallet(wallet);
            }
        }).catch((e) => {
            console.error('error publishing wallet', e);
            setState('error');
        });
    }

    const [ nutzaps, setNutzaps ] = useState(true);
    const [ mintInput, setMintInput ] = useState('');
    const [showAddMint, setShowAddMint] = useState(false);
    
    return (
        <Container skipImage>

            <View className="flex-col items-center justify-center flex-1 w-full mb-10">
                <Text className="text-white text-2xl font-bold">
                    Kickstarting your wallet
                </Text>

                <Text className="text-white/60 text-base">
                    Tap any mint you don't want
                </Text>
            </View>

            <ScrollView style={{ width: '100%', height: 200 }}>
                <View className="flex-col items-start justify-center flex-1 w-full mb-10">
                    {Array.from(mints).map((mint) => (
                        <TouchableOpacity key={mint} onPress={() => {
                            setMints(new Set(Array.from(mints).filter(m => m !== mint)));
                            rejectedMints.current.add(mint);
                        }} className="py-1 flex-row gap-2 items-center">
                            <View className="w-2 h-2 bg-green-500 rounded-full" />
                            <Text key={mint} className="text-white/60 text-sm">{mint}</Text>
                        </TouchableOpacity>
                    ))}
                    <View className="flex-row items-center justify-center gap-2">
                        {showAddMint && (
                            <TextInput
                                className="!text-white border border-gray-500 py-2 px-4 rounded-lg grow"
                                style={{ fontSize: 12, color: 'white' }}
                                autoCapitalize="none"
                                onChangeText={setMintInput}
                                autoCorrect={false}
                                autoFocus={false}
                                placeholder="Add a mint" />
                        )}

                        <Button variant="plain" onPress={() => {
                            if (showAddMint) {
                                queryMint(mintInput, mintInput);
                                setMintInput('');
                            } else {
                                setShowAddMint(!showAddMint);
                            }
                        }}>
                            <Text className="text-white text-sm">
                                {showAddMint ? 'Add' : 'Type a mint'}
                            </Text>
                        </Button>
                    </View>
                </View>

            </ScrollView>

            <View className="flex-col justify-center flex-1 w-full">
              <Button variant="plain" className="flex-row items-center justify-start gap-2 flex-1 w-full mt-5" onPress={() => setNutzaps(!nutzaps)}>
                  <Checkbox checked={nutzaps} />
                  <Text className="text-white font-medium">
                      Enable Nutzaps
                  </Text>
              </Button>
            </View>

            <View className="flex-col items-stretch justify-center flex-1 w-full">
                {mints.size > 0 ? (
                    <>
                    <Button variant="accent" className="mt-4 !py-4" onPress={createWallet} state={state}>
                        <Text className="text-white font-semibold w-full text-center">
                            Create wallet
                        </Text>
                    </Button>
                        <Button variant="plain" onPress={proceedWithoutWallet}>
                            <Text className="text-white my-3 text-sm">
                                Proceed without a wallet
                            </Text>
                        </Button>
                    </>
                ) : (
                    <Button variant="accent" className="mt-4 w-full !py-4" onPress={proceedWithoutWallet}>
                        <Text className="text-white font-semibold">
                            Proceed without a wallet
                        </Text>
                    </Button>
                )}
            </View>
        </Container>
    )
}

export default function LoaderScreen({ children }: { children: React.ReactNode }) {
    const currentUser = useNDKCurrentUser();
    const cacheInitialized = useNDKCacheInitialized();
    const { activeWallet, setActiveWallet } = useNDKWallet();
    const [ready, setReady] = useState(false);
    const [cacheReady, setCacheReady] = useState(false);
    const [userReady, setUserReady] = useState(false);
    const [proceedWithoutWallet, setProceedWithoutWallet] = useState(false);
    const [walletReady, setWalletReady] = useState<boolean | undefined>(undefined);
    const [welcome, setWelcome] = useState(false);
    const [forceCreateNewWallet, setForceCreateNewWallet] = useState(false);

    const appReady = useAtomValue(appReadyAtom);

    const wallets = useNDKSessionEvents([NDKKind.CashuWallet]);

    useEffect(() => {
        if (cacheInitialized && !cacheReady) {
            setTimeout(() => setCacheReady(true), 500);
        }
    }, [cacheInitialized]);

    useEffect(() => {
        if (activeWallet && walletReady === undefined) {
            console.log('calling activeWallet.once ready');
            activeWallet.once('ready', () => {
                setWalletReady(true);
            });
        }
    }, [activeWallet?.walletId])

    const state = useMemo(() => {
        if (!cacheInitialized) return 'initializing';
        if (!currentUser) {
            if (!userReady) return 'get-started';
            if (!welcome) return 'welcome';
            return 'login';
        }
        if ((activeWallet && walletReady) || proceedWithoutWallet) return 'ready';
        if (activeWallet && !walletReady) return 'checking-wallets';
        if (!appReady)  return 'checking-wallets';
        if (forceCreateNewWallet || (wallets.length === 0 && !activeWallet && !proceedWithoutWallet)) return 'create-new-wallet';
        if (wallets && wallets.length > 0) return 'choose-wallet';
        return 'unhandled ' + !!currentUser + ' ' + JSON.stringify(wallets);
    }, [cacheInitialized, currentUser, userReady, wallets, activeWallet?.walletId, welcome, proceedWithoutWallet, walletReady]);

    const [hadUser, setHadUser] = useState(!!currentUser);

    console.log('state', state);
    
    useEffect(() => {
        console.log('running effect to get wallets currentUser', currentUser?.pubkey);
        
        if (!currentUser && hadUser) {
            setUserReady(true);
        } else if (currentUser && !hadUser) {
            setHadUser(true);
        }
    }, [currentUser?.pubkey])

    useEffect(() => {
        if (cacheInitialized && currentUser && activeWallet) {
            activeWallet?.once('ready', () => {
                setReady(true);
            });
            setTimeout(() => setReady(true), 1000);
        }

        if (!currentUser && ready) {
            setReady(false);
        }
    }, [cacheInitialized, currentUser?.pubkey, activeWallet?.walletId]);

    function handleChooseWallet(wallet: NDKEvent) {
        NDKCashuWallet.from(wallet).then(wallet => {
            console.log('calling setActiveWallet', wallet);
            wallet.start();
            setActiveWallet(wallet);
        });
    }

    const handleCreateNewWallet = () => {
        setForceCreateNewWallet(true);
    }

    switch (state) {
        case 'initializing': return <Initializing />;
        case 'get-started': return <GetStarted onReady={() => setUserReady(true)} />;
        case 'welcome': return <Welcome onReady={() => setWelcome(true)} />;
        case 'login': return <Login />;
        case 'checking-wallets': return <CheckingWallets />;
        case 'choose-wallet': return <ChooseWallet wallets={wallets} onChoose={handleChooseWallet} onCreateNew={handleCreateNewWallet} />;
        case 'create-new-wallet': return <CreateNewWallet proceedWithoutWallet={() => setProceedWithoutWallet(true)} />;
        case 'ready': return <>{children}</>;
        default:
            return (
                <Container>
                    <Text className="text-white">
                        {JSON.stringify(state)}
                    </Text>
                </Container>
            )
    }
}
