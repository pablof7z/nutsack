import { View, Text, SafeAreaView, TouchableOpacity, ScrollView } from "react-native";
import { NDKCashuMintList, NDKEvent, NDKKind, NDKNutzap, NDKUser, useNDK, useNDKSession, useNDKSessionEventKind, useNDKSessionEvents, useSubscribe, useUserProfile } from "@nostr-dev-kit/ndk-mobile";
import { NDKCashuWallet, NDKNWCWallet, NDKWallet, NDKWalletBalance, NDKWalletChange } from "@nostr-dev-kit/ndk-wallet";
import { useEffect, useMemo, useState } from "react";
import { router, Stack, Tabs } from "expo-router";
import { formatMoney } from "@/utils/bitcoin";
import { List, ListItem } from "@/components/nativewindui/List";
import { cn } from "@/lib/cn";
import { BlurView } from "expo-blur";
import { Button } from "@/components/nativewindui/Button";
import { ArrowDown, ArrowLeft, ArrowRight, ArrowUp, BookDown, ChevronDown, Cog, Eye, Settings, ZoomIn } from "lucide-react-native";
import * as User from '@/components/ui/user';
import RelativeTime from "../components/relative-time";
import { useColorScheme } from "@/lib/useColorScheme";
import { activeEventStore, useActiveEventStore } from "@/stores";

function WalletBalance({ wallet, balance }: { wallet: NDKWallet, balance: NDKWalletBalance }) {
    function update() {
        router.push('/(wallet)')
    }

    const numberWithThousandsSeparator = (amount: number) => {
        return amount.toLocaleString();
    }

    return (
        <TouchableOpacity className="px-4 flex-col" onPress={update}>
            <View className="flex-col justify-center pt-10 rounded-lg text-center">
                <View className="flex-col items-center gap-1">
                    <Text className="text-6xl whitespace-nowrap text-foreground font-black font-mono">
                        {numberWithThousandsSeparator(balance.amount)}
                    </Text>
                    <Text className="text-lg text-foreground font-medium opacity-50 pb-1">
                        {formatMoney({ amount: balance.amount, unit: balance.unit, hideAmount: true })}
                    </Text>
                </View>
            </View>
        </TouchableOpacity>
    );
}

function WalletNWC({ wallet }: { wallet: NDKNWCWallet }) {
    const [info, setInfo] = useState<Record<string, any> | null>(null);
    wallet.getInfo().then((info) => {
        console.log('info', info);
        setInfo(info)
    });

    return <View>
        <Text>{JSON.stringify(info)}</Text>
    </View>;
}

function nicelyFormattedMintName(mint: string) {
    try {
        const url = new URL(mint);
        return url.hostname;
    } catch (e) {
        return mint;
    }
}

function HistoryItem({ wallet, item, index, target, onPress }: { wallet: NDKWallet, item: NDKEvent, index: number, target: any, onPress: () => void }) {
    const { colors } = useColorScheme();
    const { ndk } = useNDK();
    const [ nutzap, setNutzap ] = useState<NDKNutzap | null>(null);
    const [ walletChange, setWalletChange ] = useState<NDKWalletChange | null>(null);
    useEffect(() => {
        NDKWalletChange.from(item).then((walletChange) => {
            setWalletChange(walletChange);
        });
    }, [item.id]);

    const eTag = useMemo(() => walletChange?.getMatchingTags('e', 'redeemed')[0], [walletChange]);

    const nutzapCounterpart = useMemo(() => {
        if (!walletChange) return null;
        if (walletChange.direction === 'out') {
            return walletChange.tagValue('p');
        } else if (walletChange.direction === 'in') {
            const eTag = walletChange.getMatchingTags('e', 'redeemed')[0];
            return eTag ? (nutzap?.pubkey ?? eTag[4]) : null;
        }
    }, [walletChange]);

    useEffect(() => {
        if (eTag) {
            ndk.fetchEventFromTag(eTag, walletChange).then((event) => {
                if (event) {
                    setNutzap(NDKNutzap.from(event));
                }
            });
        }
    }, [eTag]);

    if (!walletChange) return null;
    if (walletChange.amount < 0) return null;

    return (
        <ListItem
            className={cn('ios:pl-0 pl-2', index === 0 && 'ios:border-t-0 border-border/25 dark:border-border/80 border-t')}
            target={target}
            leftView={<LeftView pubkey={nutzapCounterpart} walletChange={walletChange} />}
            item={{
                id: item.id,
                title: nutzapCounterpart ? null : walletChange.description,
                subTitle: nutzapCounterpart ? null : nicelyFormattedMintName(walletChange.mint)
            }}
            rightView={(
                <View className="flex-col items-end gap-0">
                    {walletChange.amount && (
                        <Text className="text-lg font-bold text-foreground">{formatMoney({ amount: walletChange.amount, unit: walletChange.unit ?? wallet.unit })}</Text>
                    )}
                    <RelativeTime timestamp={walletChange.created_at} className="text-muted-foreground" />
                </View>
            )}
            index={index}
            onPress={onPress}
        >
            {nutzapCounterpart && ( <Zapper pubkey={nutzapCounterpart} /> )}
        </ListItem>  
    )
}

const LeftView = ({ walletChange, pubkey }: { walletChange: NDKWalletChange, pubkey: string }) => {
    const { userProfile } = useUserProfile(pubkey);
    const { colors } = useColorScheme();

    const color = colors.primary;

    if (userProfile) {
        return (
            <View className="flex-row items-center gap-2 relative" style={{ marginRight: 10}}>
                {userProfile && <User.Avatar userProfile={userProfile} size={24} className="w-6 h-6" />}
                {walletChange.direction === 'out' && (
                    <View className="absolute -right-2 -top-2 rotate-45">
                        <ArrowUp size={18} color={color} />
                    </View>
                )}
                {walletChange.direction === 'in' && (
                    <View className="absolute -right-2 -bottom-2 -rotate-45">
                        <ArrowDown size={18} color={color} />
                    </View>
                )}
            </View>
        )
    }
    
    return (
        <View className="flex-row items-center gap-2 mr-2">
            {walletChange.direction === 'out' ? <ArrowUp size={24} color={color} /> : <ArrowDown size={24} color={color} />}
        </View>
    )
}

const Zapper = ({ pubkey }: { pubkey: string }) => {
    const { userProfile } = useUserProfile(pubkey);
    return (
        <View className="flex-col gap-0">
            <Text className="text-lg text-foreground">{userProfile?.name}</Text>
            <Text className="text-xs text-muted-foreground">Nutzap</Text>
        </View>
    )
}

function History({ wallet }: { wallet: NDKCashuWallet }) {
    const { currentUser } = useNDK();
    const filters = useMemo(() => [{ kinds: [NDKKind.WalletChange], authors: [currentUser?.pubkey] }], [currentUser?.pubkey])
    const { events: history } = useSubscribe({ filters });
    const { setActiveEvent } = useActiveEventStore();

    const sortedEvents = useMemo(() => {
        return history.sort((a, b) => b.created_at - a.created_at);
    }, [history]);

    const onItemPress = (item: NDKEvent) => {
        setActiveEvent(item);
        router.push('/tx');
    }

    return (
        <List
            data={sortedEvents}
            keyExtractor={(item) => item.id}
            estimatedItemSize={56}
            contentInsetAdjustmentBehavior="automatic"
            sectionHeaderAsGap
            variant="insets"
            renderItem={({ item, index, target }) => (
                <HistoryItem
                    wallet={wallet}
                    item={item}
                    index={index}
                    target={target}
                    onPress={() => onItemPress(item)}
                />
            )}
        />
    )
}

function WalletNip60({ wallet }: { wallet: NDKCashuWallet }) {
    return (
        <View className="flex-1 flex-col h-full min-h-[100px]">
            <History wallet={wallet} />
        </View>
    );
}

function WalletHeader({ activeWallet }: { activeWallet: NDKWallet }) {
    const { colors } = useColorScheme();
    
    if (activeWallet instanceof NDKCashuWallet) {
        const title = activeWallet?.name || activeWallet?.type || 'Honeypot';
        return <TouchableOpacity className="flex-row items-center gap-2" onPress={() => router.push('/(wallet)')}>
            <Text className="text-lg text-muted-foreground font-medium">{title}</Text>
            <ChevronDown size={24} color={colors.muted} />
        </TouchableOpacity>;
    }

    return <Text>Honeypot</Text>
}

export default function WalletScreen() {
    const { ndk, currentUser } = useNDK();
    const { activeWallet, balances, setActiveWallet } = useNDKSession();
    const { colors } = useColorScheme();
    const mintList = useNDKSessionEventKind<NDKCashuMintList>(NDKCashuMintList, NDKKind.CashuMintList, { create: true });

    console.log('mint list', JSON.stringify(mintList?.rawEvent(), null, 4));

    const isNutzapWallet = useMemo(() => {
        if (!(activeWallet instanceof NDKCashuWallet)) return false;
        if (!mintList) return false;
        return mintList.p2pk === activeWallet.p2pk;
    }, [activeWallet, mintList]);

    const setNutzapWallet = async () => {
        try {
            if (!mintList || !(activeWallet instanceof NDKCashuWallet)) return;
            mintList.ndk = ndk;
            console.log('setNutzapWallet', activeWallet.event.rawEvent(), mintList.rawEvent());
            mintList.p2pk = activeWallet.p2pk;
            mintList.mints = activeWallet.mints;
            mintList.relays = activeWallet.relays;
            await mintList.sign();
            mintList.publishReplaceable();
            console.log('mintList', JSON.stringify(mintList.rawEvent(), null, 2));
        } catch (e) {
            console.error('error', e);
        }
    }

    return (
        <>
            <Tabs.Screen
                options={{
                    headerShown: true,
                    headerTransparent: true,
                    headerBackground: () => <BlurView intensity={100} tint="light" />,  
                    headerRight: () => <TouchableOpacity className="pr-2" onPress={() => router.push('/(wallet)/(settings)')}>
                        <Settings size={24} color={colors.foreground} />
                    </TouchableOpacity>
                }}
            />
            <SafeAreaView className="flex-1 bg-card">
                <View className="flex-1 flex-col">
                    <View className="flex-col grow">
                        {/* {!isNutzapWallet && (
                            <Button onPress={setNutzapWallet}>
                                <Text>Enable Nutzaps</Text>
                            </Button>
                        )} */}
                        
                        {balances.length > 0 && <WalletBalance wallet={activeWallet} balance={balances[0]} />}
                        {activeWallet instanceof NDKNWCWallet && <WalletNWC wallet={activeWallet} />}
                        {activeWallet instanceof NDKCashuWallet && <WalletNip60 wallet={activeWallet} />}
                    </View>

                    <Footer activeWallet={activeWallet} currentUser={currentUser} />
                </View>
            </SafeAreaView>
            </>
    );
}

function Footer({ activeWallet, currentUser }: { activeWallet: NDKWallet, currentUser: NDKUser }) {
    if (activeWallet) {
        return <WalletButtons />
    } else if (currentUser) {
        return <EnableWallet />
    } else {
        return <LoginButton />
    }
}

function LoginButton() {
    const login = () => router.push('/login')
    
    return (
        <View className="flex-row justify-stretch p-4 gap-14">
            <Button variant="primary" className="grow items-center" onPress={login}>
                <Text className="py-2 text-white font-medium">Login</Text>
            </Button>
        </View>
    )
}

function EnableWallet() {
    return (
        <View className="flex-row justify-stretch p-4 gap-14">
            <Button variant="primary" className="grow items-center" onPress={() => router.push('/(settings)/wallets')}>
                <Text className="py-2 text-white font-medium">Enable Wallet</Text>
            </Button>
        </View>
    )
}

function WalletButtons() {
    const receive = () => router.push('/receive')
    const send = () => router.push('/send')
    
    return (
        <View className="flex-row justify-stretch p-4 gap-14">
            <Button variant="secondary" className="grow items-center" onPress={receive}>
                <Text className="py-2 text-foreground font-mono font-medium uppercase">Receive</Text>
            </Button>
            <Button variant="secondary" className="grow items-center" onPress={send}>
                <Text className="py-2 text-foreground font-mono font-medium uppercase">Send</Text>
            </Button>
        </View>
    )
}