import 'react-native-get-random-values';
import React, { useEffect, useState } from 'react';
import { StyleSheet, TextInput, Alert, KeyboardAvoidingView, Platform, View, Dimensions } from 'react-native';
import { CameraView } from 'expo-camera';
import { useNDK } from '@nostr-dev-kit/ndk-mobile';
import { NDKPrivateKeySigner } from '@nostr-dev-kit/ndk-mobile';
import { nip19 } from 'nostr-tools';
import { Text } from '@/components/nativewindui/Text';
import { Button } from '@/components/nativewindui/Button';
import { QrCode } from 'lucide-react-native';
import { cn } from '@/lib/cn';

export default function LoginComponent({ textClassName }: { textClassName?: string }) {
    const [payload, setPayload] = useState<string | undefined>(undefined);
    const { ndk, loginWithPayload, currentUser } = useNDK();

    const handleLogin = async () => {
        if (!ndk) return;
        try {
            await loginWithPayload(payload, { save: true });
        } catch (error) {
            Alert.alert('Error', error.message || 'An error occurred during login');
        }
    };

    const createAccount = async () => {
        const signer = NDKPrivateKeySigner.generate();
        const nsec = nip19.nsecEncode(signer._privateKey!);
        await loginWithPayload(nsec, { save: true });
    };

    const [scanQR, setScanQR] = useState(false);

    async function handleBarcodeScanned({ data }: { data: string }) {
        setPayload(data.trim());
        setScanQR(false);
        try {
            await loginWithPayload(data.trim(), { save: true });
        } catch (error) {
            Alert.alert('Error', error.message || 'An error occurred during login');
        }
    }

    return (
        <View className="w-full flex-col items-center flex-1 justify-center">
            <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : 'height'} style={styles.container}>
                <View className="w-full flex-1 items-stretch justify-center gap-4">
                    {scanQR && (
                        <View style={{ borderRadius: 8, height: Dimensions.get('window').width * 0.75, width: Dimensions.get('window').width *0.75 }}>
                            <CameraView
                                barcodeScannerSettings={{
                                    barcodeTypes: ['qr']
                                }}
                                style={{ flex: 1, width: '100%', borderRadius: 8 }}
                                onBarcodeScanned={handleBarcodeScanned}
                            />
                        </View>
                    )}

                    <View className="flex-col items-start gap-1 w-full">
                        <Text className={cn(textClassName, 'text-base')}>
                            Enter your nsec or bunker:// connection
                        </Text>
                        <TextInput
                            style={styles.input}
                            className={textClassName}
                            multiline
                            autoCapitalize="none"
                            autoComplete={undefined}
                            placeholder="Enter your nsec or bunker:// connection"
                            autoCorrect={false}
                            value={payload}
                            onChangeText={setPayload}
                        />
                    </View>

                    <Button variant="accent" size={Platform.select({ ios: 'lg', default: 'md' })} onPress={handleLogin}>
                        <Text>Login</Text>
                    </Button>

                    <Button variant="plain" onPress={createAccount}>
                        <Text className={textClassName}>New to nostr?</Text>
                    </Button>

                    {!scanQR && (
                        <View className='flex-row justify-center w-full'>
                            <Button variant="secondary" onPress={() => {
                                ndk.signer = undefined;
                                setScanQR(true);
                            }} className="" style={{ flexDirection: 'column', gap: 8 }}>
                                <QrCode size={64} />
                                <Text className={textClassName}>Scan QR</Text>
                            </Button>
                        </View>
                    )}
                </View>
            </KeyboardAvoidingView>
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        width: '100%',
    },
    input: {
        width: '100%',
        height: 100,
        borderColor: 'gray',
        borderWidth: 1,
        borderRadius: 5,
        padding: 10,
    },
    button: {
        textAlign: 'center',
        padding: 20,
        borderRadius: 99,
        marginBottom: 10,
        width: '100%',
    },
    buttonText: {
        color: 'white',
        fontSize: 20,
        fontWeight: 'bold',
        textAlign: 'center',
    },
});
