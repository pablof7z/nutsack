import { useEffect, useMemo, useRef, useState } from "react";
import { ActivityIndicator } from "./nativewindui/ActivityIndicator";
import { Button, ButtonState } from "./nativewindui/Button";
import { Text } from "./nativewindui/Text";
import { NDKCashuMintList, NDKEvent, NDKKind, NDKSubscription, useNDK, useNDKSession, useSubscribe } from "@nostr-dev-kit/ndk-mobile";
import { View, Image, TextInput, TouchableOpacity, Touchable, TouchableWithoutFeedback } from "react-native";
import LoginComponent from "./login";
import { Bolt } from "lucide-react-native";
import { CashuMint, CashuWallet } from "@cashu/cashu-ts";
import { NDKCashuWallet } from "@nostr-dev-kit/ndk-wallet";
import { ScrollView } from "react-native";
import { Checkbox } from "./nativewindui/Checkbox";

function Container({ skipImage, children }: { skipImage?: boolean, children?: React.ReactNode }) {
    const { currentUser, logout } = useNDK();
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
            <Button variant="accent" className="mt-4 w-full" onPress={onReady}>
                <Text className="text-white font-semibold py-3">
                    Get Started
                </Text>
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

function NoWallet({ proceedWithoutWallet }: { proceedWithoutWallet: () => void }) {
    const { ndk } = useNDK();
    const { setActiveWallet } = useNDKSession();

    const [ queryingMints, setQueryingMints ] = useState(new Set<string>());
    const [ mints, setMints ] = useState(new Set<string>());

    const sub = useRef<NDKSubscription | null>(null);

    const queryMint = (url: string, normalizedUrl: string) => {
        setQueryingMints(prev => new Set([...prev, normalizedUrl]));
        console.log('querying mint', normalizedUrl);
        const mint = new CashuMint(url);
        const w = new CashuWallet(mint);
        w.createMintQuote(1000).then(info => {
            if (info) {
                console.log('adding mint', url);
                mints.add(url);
                setMints(new Set(mints));
            } else {
                console.log('failed to query mint', url);
            }
        });
    }

    if (!sub.current) {
        sub.current = ndk.subscribe([{ kinds: [38172], limit: 500 }], { groupable: false, closeOnEose: true, subId: 'mints' }, undefined, false);
        sub.current.on('event', (event) => {
            const url = event.tagValue('u');
            const normalizedUrl = new URL(url).hostname;
            if (!queryingMints.has(normalizedUrl)) {
                queryMint(url, normalizedUrl);
            }
        });
        sub.current.start();
    }
    
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
                    setActiveWallet(wallet);
                });
            } else {
                setActiveWallet(wallet);
            }
        }).catch((e) => {
            console.error('error publishing wallet', e);
            setState('error');
        });
    }

    const [ nutzaps, setNutzaps ] = useState(true);
    
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
                        }} className="py-1 flex-row gap-2 items-center">
                            <View className="w-2 h-2 bg-green-500 rounded-full" />
                            <Text key={mint} className="text-white/60 text-sm">{mint}</Text>
                        </TouchableOpacity>
                    ))}
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

            <View className="flex-col items-center justify-center flex-1 w-full">
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
    const { currentUser, cacheInitialized, ndk } = useNDK();
    const { activeWallet, setActiveWallet } = useNDKSession();
    const [ready, setReady] = useState(false);
    const [cacheReady, setCacheReady] = useState(false);
    const [userReady, setUserReady] = useState(false);
    const [wallets, setWallets] = useState<NDKEvent[] | 'checking' | undefined>(undefined);
    const [proceedWithoutWallet, setProceedWithoutWallet] = useState(false);
    const [walletReady, setWalletReady] = useState<boolean | undefined>(undefined);

    useEffect(() => {
        if (cacheInitialized && !cacheReady) {
            setTimeout(() => setCacheReady(true), 500);
        }
    }, [cacheInitialized]);

    useEffect(() => {
        if (activeWallet && walletReady === undefined) {
            activeWallet.once('ready', () => {
                setWalletReady(true);
            });
        }
    }, [activeWallet])

    const state = useMemo(() => {
        if (!cacheInitialized) return 'initializing';
        if (!currentUser && !userReady) return 'get-started';
        if (!currentUser) return 'login';
        if ((activeWallet && walletReady) || proceedWithoutWallet) return 'ready';
        if (activeWallet && !walletReady) return 'checking-wallets';
        if (wallets && (wallets === 'checking' || wallets.length === 0)) return 'checking-wallets';
        if (wallets === null && !activeWallet && !proceedWithoutWallet) return 'no-wallet';
        if (wallets && wallets.length > 0) return 'choose-wallet';
        return 'unhandled' + !!currentUser + JSON.stringify(wallets);
    }, [cacheInitialized, currentUser, userReady, wallets, activeWallet, proceedWithoutWallet, walletReady]);

    const [ hadUser, setHadUser ] = useState(!!currentUser);
    
    useEffect(() => {
        if (!currentUser && hadUser) {
            setUserReady(true);
        } else if (currentUser && !hadUser) {
            setHadUser(true);
        }

        let fetchWallets = [];
        
        if (currentUser && wallets === undefined) {
            setWallets('checking');
            // check if user has a wallet
            const sub = ndk.subscribe([{ kinds: [NDKKind.CashuWallet], authors: [currentUser.pubkey] }], { groupable: false, closeOnEose: true, subId: 'wallets' }, undefined, false);
            sub.on('event', (event) => {
                fetchWallets.push(event);
            });
            sub.on('eose', () => {
                if (fetchWallets.length === 1) {
                    NDKCashuWallet.from(fetchWallets[0]).then(wallet => {
                        setActiveWallet(wallet);
                    });
                } else if (fetchWallets.length === 0) {
                    setWallets(null);
                } else {
                    setWallets(fetchWallets);
                }
            });
            sub.start();
        }
    }, [currentUser])

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
    }, [cacheInitialized, currentUser, activeWallet]);

    function handleChooseWallet(wallet: NDKEvent) {
        NDKCashuWallet.from(wallet).then(wallet => {
            setActiveWallet(wallet);
        });
    }

    function handleCreateNewWallet() {
        setWallets(null);
    }

    switch (state) {
        case 'initializing': return <Initializing />;
        case 'get-started': return <GetStarted onReady={() => setUserReady(true)} />;
        case 'login': return <Login />;
        case 'checking-wallets': return <CheckingWallets />;
        case 'choose-wallet': return <ChooseWallet wallets={wallets} onChoose={handleChooseWallet} onCreateNew={handleCreateNewWallet} />;
        case 'no-wallet': return <NoWallet proceedWithoutWallet={() => setProceedWithoutWallet(true)} />;
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
