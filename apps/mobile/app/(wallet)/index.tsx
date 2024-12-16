import { useNDKSession } from "@nostr-dev-kit/ndk-mobile";
import { NDKCashuWallet } from "@nostr-dev-kit/ndk-wallet";
import { List, ListItem } from "@/components/nativewindui/List";
import { Text } from "@/components/nativewindui/Text";
import { View } from 'react-native';
import { cn } from "@/lib/cn";
import { formatMoney } from "@/utils/bitcoin";
import { useMemo } from "react";
import { PieChart } from "react-native-gifted-charts";

export default function Index() {
    const { activeWallet } = useNDKSession();
    
    if (!(activeWallet instanceof NDKCashuWallet)) return null;
    
    const mintBalances = useMemo(() => activeWallet.mintBalances, [activeWallet]);

    return (
        <>
            <View className="flex-1 bg-card">
                <Chart mintBalances={mintBalances} />
                <MintBalances wallet={activeWallet} />
            </View>
        </>
    )
}

function Chart({ mintBalances }: { mintBalances: Record<string, number> }) {
    
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
                centerLabelComponent={() => (
                    <Text style={{ fontSize: 18, fontWeight: 'bold' }}>
                        {Object.keys(mintBalances).length} Mints
                    </Text>
                )}
            />
        </View>
    )
}

function MintBalances({ wallet }: { wallet: NDKCashuWallet }) {
    const mintBalances = wallet.mintBalances;

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