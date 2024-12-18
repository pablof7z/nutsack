import { LargeTitleHeader } from "@/components/nativewindui/LargeTitleHeader";
import { List, ListItem } from "@/components/nativewindui/List";
import { StyleSheet } from "react-native";
import { ActivityIndicator } from "@/components/nativewindui/ActivityIndicator";
import { CashuPaymentInfo, Hexpubkey, NDKKind, NDKLnUrlData, NDKUser, NDKUserProfile, NDKZapMethodInfo, NDKZapper, useNDK, useNDKSession, useSubscribe, useUserProfile } from "@nostr-dev-kit/ndk-mobile";
import { TextInput, TouchableOpacity, View, KeyboardAvoidingView } from "react-native";
import * as User from "@/components/ui/user"
import { Text } from "@/components/nativewindui/Text";
import { useEffect, useMemo, useRef, useState } from "react";
import { Button, ButtonProps } from "@/components/nativewindui/Button";
import WalletBalance from "@/components/ui/wallet/WalletBalance";
import { NDKCashuWallet } from "@nostr-dev-kit/ndk-wallet";
import { router, Stack } from "expo-router";
import { toast } from "@backpackapp-io/react-native-toast";
import { useAppStateStore } from "@/stores";
import { KeyboardAwareScrollView } from "react-native-keyboard-controller";

export function UserAsHeader({ pubkey }: { pubkey: Hexpubkey }) {
    const { userProfile } = useUserProfile(pubkey);
    return (
        <View className="flex-1 flex-col items-center gap-2">
            <User.Avatar userProfile={userProfile} size={24} className="w-20 h-20" />
            <Text className="text-xl font-bold">
                <User.Name userProfile={userProfile} pubkey={pubkey} />
            </Text>
        </View>
    )
}

function SendToUser({ pubkey, onCancel }: { pubkey: Hexpubkey, onCancel: () => void }) {
    const { ndk } = useNDK();
    const { activeWallet, balances } = useNDKSession();
    const inputRef = useRef<TextInput | null>(null);
    const [amount, setAmount] = useState(21);
    const user = useMemo(() => ndk.getUser({ pubkey }), [pubkey]);
    const zap = useMemo(() => new NDKZapper(user, 0, 'msat', {
        comment: "Honeypot nutzap"
    }), [pubkey, amount]);
    const [methods, setMethods] = useState<NDKZapMethodInfo[]>([]);
    const [buttonState, setButtonState] = useState<ButtonState>('idle');
    const { addPendingPayment } = useAppStateStore();

    useEffect(() => {
        zap.amount = amount * 1000;
        zap.getZapMethods(ndk, pubkey).then(setMethods);
    }, [pubkey]);

    async function send() {
        setButtonState('pending');
        zap.amount = amount * 1000;
        zap.once("complete", (split, info) => {
            setButtonState('idle');
        });
        // zap.zap();
        addPendingPayment(zap);
        setTimeout(() => {
            router.back();
        }, 500);
    }
    
    return (
        <KeyboardAwareScrollView>
            <View className="flex-1 flex-col items-center gap-2 pt-5 w-full">
                <View className="flex-1 flex-row items-center w-full justify-between gap-2 p-2 absolute">
                    <Button variant="plain" className="w-fit" onPress={onCancel}>
                        <Text className="text-base text-muted-foreground">Cancel</Text>
                    </Button>

                    <StateButton variant="plain" state={buttonState} onPress={send}>
                        <Text className="">Send</Text>
                    </StateButton>
                </View>

                <UserAsHeader pubkey={pubkey} />

            <View className="flex-1 flex-col items-center gap-2">
                <TextInput
                    ref={inputRef}
                    keyboardType="numeric" 
                    autoFocus
                    style={styles.input} 
                    value={amount.toString()}
                    onChangeText={(text) => setAmount(Number(text))}
                />

                <WalletBalance
                    amount={amount}
                    unit={(activeWallet as NDKCashuWallet).unit}
                    onPress={() => inputRef.current?.focus()}
                />
            </View>

            <View className="flex flex-col gap-2 w-full">
                {methods.map((method) => (
                    <View key={method.type} className="mx-4">
                        <Text className="text-xl font-bold py-2">{method.type.toUpperCase()}</Text>

                        {method.type === 'nip61' && (
                            <View className="flex flex-col gap-2">
                                {(method.data as CashuPaymentInfo).mints.map((mint) => {
                                    return <Text key={mint} className="text-sm text-muted-foreground">{mint}</Text>
                                })}
                            </View>
                        )}

                        {method.type === 'nip57' && (
                            <View className="flex flex-col gap-2">
                                <Text className="text-base font-medium py-2">{(method.data as NDKLnUrlData).callback}</Text>
                            </View>
                        )}
                    </View>
                ))}
            </View>

            </View>
        </KeyboardAwareScrollView>
    )
}

type ButtonState = 'idle' | 'pending' | 'complete' | 'error';

function StateButton({ variant, state, onPress, children }: { variant: ButtonProps["variant"], state: ButtonState, onPress: () => void, children: React.ReactNode }) {
    return <Button variant={variant} onPress={onPress} disabled={state !== 'idle'}>
        {state === 'idle' && children}
        {state === 'pending' && <ActivityIndicator size="small" color="white" className="my-3" />}
    </Button>
}

function FollowItem({ index, target, item, onPress }: { index: number, target: ListItemTarget, item: string, onPress: () => void }) {
    const {userProfile} = useUserProfile(item);
    
    return <ListItem
        index={index}
        target={target}
        item={{
            id: item,
            title: ""
        }}
        leftView={<TouchableOpacity className="flex-row items-center p-2" onPress={onPress}>
            <User.Avatar userProfile={userProfile} size={16} className="w-10 h-10 mr-2" />
            <User.Name userProfile={userProfile} pubkey={item} className="text-lg text-foreground" />
        </TouchableOpacity>}
    />
}

export default function SendView() {
    const { ndk } = useNDK();
    const [search, setSearch] = useState('');
    const [selectedPubkey, setSelectedPubkey] = useState<Hexpubkey | null>(null);

    const mintlistFilter = useMemo(() => [{ kinds: [NDKKind.CashuMintList] }], []);
    const { events: mintlistEvents } = useSubscribe({ filters: mintlistFilter });

    const usersWithMintlist = useMemo(() => {
        return mintlistEvents.map((event) => event.pubkey);
    }, [mintlistEvents]);

    if (selectedPubkey) {
        return (<SendToUser pubkey={selectedPubkey} onCancel={() => setSelectedPubkey(null)} />)
    }

    async function getUser() {
        if (search.startsWith('npub')) {
            try {
                const user = ndk.getUser({ npub: search });
                setSelectedPubkey(user.pubkey);
                return;
            } catch (error) {
                console.error(error);
            }
        }

        try {
            const user = await NDKUser.fromNip05(search, ndk);
            if (user) {
                setSelectedPubkey(user.pubkey);
                return;
            }
        } catch { }

        toast.error("Couldn't find anyone with that");
    }
    

    return (
        <>
            <View className="flex-1">
                <View className="flex-col gap-2">
                <TextInput
                    className="text-base bg-muted/40 text-foreground m-4 rounded-lg p-2"
                    placeholder="Enter a Nostr address or npub"
                    value={search}
                    onChangeText={setSearch}
                />

                <Button variant="primary" className="mb-4 mx-4 flex-none h-10" onPress={getUser}>
                    <Text className="text-xl font-medium">Search</Text>
                </Button>
            </View>

            <List
                data={usersWithMintlist}
                keyExtractor={(item) => item}
                contentInsetAdjustmentBehavior="automatic"
                estimatedItemSize={56}
                sectionHeaderAsGap
                variant="insets"
                renderItem={({ index, target, item }) => (
                    <FollowItem
                        index={index}
                        target={target}
                        item={item}
                        onPress={() => setSelectedPubkey(item)}
                    />
                )}
            />
        </View>
        </>
    )
}

const styles = StyleSheet.create({
    input: {
        fontSize: 10,
        width: 0,
        textAlign: 'center',
        fontWeight: 'bold',
        backgroundColor: 'transparent',
    },
});
