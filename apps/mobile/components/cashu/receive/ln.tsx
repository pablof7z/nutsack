import { Picker } from "@react-native-picker/picker";
import { Text } from "@/components/nativewindui/Text";
import { NDKCashuWallet } from "@nostr-dev-kit/ndk-wallet";
import * as Clipboard from 'expo-clipboard';
import QRCode from 'react-native-qrcode-svg';
import { memo, useCallback, useEffect, useMemo, useRef, useState } from "react";
import { FlatList, StyleSheet } from "react-native";
import { TouchableOpacity, View } from "react-native";
import { TextInput } from "react-native-gesture-handler";
import { useNDKWallet } from "@nostr-dev-kit/ndk-mobile";
import WalletBalance from "@/components/ui/wallet/WalletBalance";
import { useColorScheme } from "@/lib/useColorScheme";
import { Button, ButtonState } from "@/components/nativewindui/Button";
import { Check } from "lucide-react-native";
import { router } from "expo-router";
import { List, ListItem } from "@/components/nativewindui/List";
import { KeyboardAwareScrollView } from "react-native-keyboard-controller";
import { ActivityIndicator } from "@/components/nativewindui/ActivityIndicator";

export default function ReceiveLn({ onReceived }: { onReceived: () => void }) {
    const { colors } = useColorScheme();
    const { activeWallet } = useNDKWallet();
    const [qrCode, setQrCode] = useState<string | null>(null);
    const inputRef = useRef<TextInput | null>(null);
    const [amount, setAmount] = useState(1000);
    const [copyState, setCopyState] = useState<ButtonState>('idle');
    const [isLoading, setIsLoading] = useState(false);

    function copy() {
        Clipboard.setStringAsync(qrCode);
        setCopyState('success');
        setTimeout(() => {
            setCopyState('idle');
        }, 2000);
    }

    const handleContinue = async (mint: string) => {
        setIsLoading(true);
        if (!mint) {
            console.error('No mint selected');
            return;
        }
        console.log('will deposit', { amount, mint });
        const deposit = (activeWallet as NDKCashuWallet).deposit(amount, mint);

        deposit.on("success", (token) => {
            console.log('success', token);
            onReceived();
        });
        
        const qr = await deposit.start();
        console.log('qr', qr);
        setQrCode(qr);
        setIsLoading(false);
    }

    const mints = useMemo(() => Array.from(new Set((activeWallet as NDKCashuWallet).mints)), [activeWallet]);

    if (!(activeWallet as NDKCashuWallet)) return (
        <View>
            <Text>
                No wallet found
            </Text>
        </View>
    )
    
    return (
        <KeyboardAwareScrollView style={{ flex: 1 }}>
            <TextInput
                ref={inputRef}
                keyboardType="numeric" 
                autoFocus
                style={styles.input} 
                value={amount.toString()}
                onChangeText={(text) => setAmount(Number(text) ?? 0)}
            />

            <WalletBalance
                amount={amount}
                unit={(activeWallet as NDKCashuWallet).unit}
                onPress={() => inputRef.current?.focus()}
            />

            {qrCode ? (
                <View className="flex-col items-stretch justify-center gap-4 px-8">
                    <View style={styles.qrCodeContainer}>
                        <QRCode value={qrCode} size={350} />
                    </View>

                    <Button variant="secondary" onPress={copy}>
                        {copyState === 'success' ? (
                            <View className="flex-row gap-1">
                                <Check color={colors.foreground} />
                                <Text>Copied</Text>
                            </View>
                        ) : <Text>Copy</Text>}
                    </Button>

                    <Button variant="plain" onPress={() => router.push({ pathname: '/beg', params: { bolt11: qrCode, otherParam: 'value' } })}>
                        <Text>Beg for money on nostr</Text>
                    </Button>
                </View>
            ) : (
                <>
                    {isLoading && <ActivityIndicator />}
                        <FlatList
                            data={mints}
                            contentInsetAdjustmentBehavior="automatic"
                            renderItem={({item, index, target}) => (
                                <ListItem
                                    onPress={() => handleContinue(item)}
                                    index={index}
                                    target={target}
                                    item={{
                                        id: item,
                                        title: item
                                    }}
                                />
                            )}
                        />
                </>
            )}
        </KeyboardAwareScrollView>
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
    amount: {
        fontSize: 72,
        marginTop: 10,
        width: '100%',
        textAlign: 'center',
        fontWeight: '900',
        backgroundColor: 'transparent',
    },
    mint: {
        fontSize: 18,
        textAlign: 'center',
        marginVertical: 8,
        fontWeight: 'bold',
    },
    selectedMint: {
        fontSize: 18,
        textAlign: 'center',
        marginVertical: 8,
        fontWeight: 'bold',
    },
    mintContainer: {
        // Add styles for the container if needed
    },
    selectedMintText: {
        // Add styles for the selected text if needed
    },
    unit: {
        fontSize: 24, // Adjusted font size for smaller display
        width: '100%',
        textAlign: 'center',
        fontWeight: '400', // Optional: adjust weight if needed
        backgroundColor: 'transparent',
    },
    picker: {
        height: 50,
        width: '100%',
    },
    continueButton: {
        backgroundColor: '#007BFF', // Button background color
        padding: 20, // Padding for the button
        borderRadius: 5, // Rounded corners
        alignItems: 'center', // Center the text
        marginTop: 20, // Space above the button
        width: '60%', // Set a narrower width for the button
        alignSelf: 'center', // Center the button horizontally
    },
    continueButtonText: {
        color: '#FFFFFF', // Text color
        fontSize: 16, // Font size
        fontWeight: 'bold', // Bold text
    },
    qrCodeContainer: {
        alignItems: 'center', // Center-aligns the QR code
        justifyContent: 'center', // Center vertically
    },
});
