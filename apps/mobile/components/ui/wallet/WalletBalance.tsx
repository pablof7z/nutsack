import { NDKWallet, NDKWalletBalance } from "@nostr-dev-kit/ndk-wallet";
import { TouchableOpacity, View } from "react-native";
import { Text } from "@/components/nativewindui/Text";
import { formatMoney } from "~/utils/bitcoin";

export default function WalletBalance({ amount, unit, onPress }: { amount: number, unit: string, onPress: () => void }) {
    let fontSize = 80;
    
    const numberWithThousandsSeparator = (amount: number) => {
        return amount.toLocaleString();
    }

    const numberStr = numberWithThousandsSeparator(amount);
    const numberStrLength = numberStr.length;

    if (numberStrLength < 4) {  
        fontSize = 120;
    } else if (numberStrLength < 6) {
        fontSize = 100;
    } else if (numberStrLength < 8) {
        fontSize = 80;
    } else if (numberStrLength < 10) {
        fontSize = 60;
    }

    return <TouchableOpacity className="p-4 flex-col" onPress={onPress}>
        <View className="flex-col justify-center pt-10 rounded-lg text-center">
            <View className="flex-col items-center gap-1">
                <Text
                    className="whitespace-nowrap text-foreground font-black font-mono"
                    style={{ fontSize, lineHeight: fontSize + 10 }}
                >
                    {numberStr}  
                </Text>
                <Text className="text-lg text-foreground font-medium opacity-50 pb-1 font-mono">
                    {formatMoney({ amount, unit: unit, hideAmount: true })}
                </Text>
            </View>
        </View>
    </TouchableOpacity>;
}