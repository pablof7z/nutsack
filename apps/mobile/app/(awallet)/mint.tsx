import { useNDKSession } from "@nostr-dev-kit/ndk-mobile";
import { NDKCashuWallet } from "@nostr-dev-kit/ndk-wallet";
import { List, ListItem } from "@/components/nativewindui/List";
import { Text } from "@/components/nativewindui/Text";
import { SafeAreaView, ScrollView, View } from 'react-native';
import { cn } from "@/lib/cn";
import { formatMoney } from "@/utils/bitcoin";
import { useMemo, useRef } from "react";
import { PieChart } from "react-native-gifted-charts";
import { useColorScheme } from "@/lib/useColorScheme";
import { FlashList } from "@shopify/flash-list";
import { useSafeAreaInsets } from "react-native-safe-area-context";

export default function Index() {
    const { activeWallet } = useNDKSession();
    const insets = useSafeAreaInsets();
    
    if (!(activeWallet instanceof NDKCashuWallet)) return null;
    
    const mintBalances = useMemo(() => activeWallet.mintBalances, [activeWallet]);

    return (
        <ScrollView className="flex-1 p-4 bg-card" style={{ paddingTop: insets.top }}>
            <View className="flex-col gap-1 items-start justify-start text-left w-full">
                <Text className="text-xl font-bold text-left">Mints</Text>
                <Text className="text-muted-foreground">{activeWallet.mints.length} mints</Text>
            </View>
            <Chart mintBalances={mintBalances} />
            <MintBalances wallet={activeWallet} />

            <Tokens wallet={activeWallet} />
        </ScrollView>
    )
}

function Chart({ mintBalances }: { mintBalances: Record<string, number> }) {
    const { colors } = useColorScheme();
    const chartData = useMemo(() => {
        return Object.entries(mintBalances).map(([mint, balance], index) => {
            const url = new URL(mint);
            const hostname = url.hostname;
            const shade = Math.floor((255 / Object.keys(mintBalances).length) * index);
            const color = `rgb(${255 - shade}, ${shade / 2}, ${155 + shade / 3})`;
            return {
                name: hostname,
                balance,
                color,
            };
        });
    }, [mintBalances]);
    
    return (
        <View style={{ alignItems: 'center', paddingHorizontal: 10, marginVertical: 20 }}>
            <PieChart
                data={chartData.map(item => ({
                    value: item.balance,
                    color: item.color,
                }))}
                donut
                radius={150}
                innerRadius={100}
                backgroundColor={colors.grey6}
                centerLabelComponent={() => (
                    <Text style={{ fontSize: 18, fontWeight: 'bold', color: colors.foreground }}>
                        {Object.keys(mintBalances).length} Mints
                    </Text>
                )}
            />
        </View>
    )
}

function MintBalances({ wallet }: { wallet: NDKCashuWallet }) {
    const mintBalances = wallet.mintBalances;

    // add the mints with a zero balance to the list
    for (const mint of wallet.mints) {
        if (!(mint in mintBalances)) {
            mintBalances[mint] = 0;
        }
    }

    return (
        <List
            data={Object.keys(mintBalances)}
            keyExtractor={(item) => item}
            estimatedItemSize={56}
            contentInsetAdjustmentBehavior="automatic"
            sectionHeaderAsGap
            variant="insets"
            renderItem={({ item, index, target }) => (
                <ListItem
                    className={cn('ios:pl-0 pl-2', index === 0 && 'ios:border-t-0 border-border/25 dark:border-border/80 border-t')}
                    target={target}
                    item={{
                        id: item,
                        title: item,
                    }}
                    rightView={<Text className="text-muted-foreground">{formatMoney({ amount: mintBalances[item], unit: wallet.unit })}</Text>}
                    index={index}
                    onPress={() => console.log('onPress')}
                />  
            )}
        />
    )
}

function Tokens({ wallet }: { wallet: NDKCashuWallet }) {
    const { colors } = useColorScheme();

    if (!(wallet instanceof NDKCashuWallet)) return null;
    
    const unit = wallet.unit;
    const tokens = wallet.tokens;
    let proofCount = 0;
    const proofsByValue = useMemo(() => {
        const values: Record<number, number> = {};

        tokens.forEach((token) => {
            token.proofs.forEach((proof) => {
                values[proof.amount] = (values[proof.amount] ?? 0) + 1;
                proofCount++;
            });
        });

        return values;
    }, [tokens]);

    const chartData = useMemo(() => {
        return Object.entries(proofsByValue).map(([amount, count], index) => {
            const shade = Math.floor((255 / Object.keys(proofsByValue).length) * index);
            const color = `rgb(${255 - shade}, ${shade / 2}, ${155 + shade / 3})`;
                                                                        
            return {
                amount,
                count,
                color,
            };
        });
    }, [proofsByValue]);

    return (
        <View className="flex-1 items-center w-full my-10">
            <View className="flex-col gap-1 items-start justify-start text-left w-full">
                <Text className="text-xl font-bold text-left">Proofs</Text>
                <Text className="text-muted-foreground">{proofCount} proofs, in {tokens.length} tokens</Text>
            </View>
            
            <View className="items-center my-4">
                <PieChart
                    data={chartData.map(item => ({
                        value: item.count,
                        color: item.color,
                    }))}
                    donut
                    radius={150}
                    innerRadius={0}
                    centerLabelComponent={() => (
                        <Text style={{ fontSize: 18, fontWeight: 'bold' }}>
                            {tokens.length} Tokens
                        </Text>
                    )}
                />
            </View>

            <View style={{ flex: 1, width: '100%' }}>
                <FlashList
                    data={chartData}
                    renderItem={({ item }) => (
                        <View style={{ flexDirection: 'row', alignItems: 'center', marginVertical: 5, paddingHorizontal: 10, width: '100%' }}>
                            <View style={{ width: 20, height: 20, backgroundColor: item.color, marginRight: 10 }} />
                            <Text style={{ flex: 1 }}>{`${item.amount} ${unit}`}</Text>
                            <Text style={{ flex: 1, marginRight: 10 }} color={colors.foreground}>
                                {`${item.count} proofs`}
                            </Text>
                            <Text style={{ flex: 0 }}>
                                {`${Number(item.amount) * item.count} ${unit}`}
                            </Text>
                        </View>
                    )}
                    estimatedItemSize={50}
                    keyExtractor={(item) => item.amount}
                    contentContainerStyle={{ paddingBottom: 20 }}
                />
            </View>
        </View>
    );
}