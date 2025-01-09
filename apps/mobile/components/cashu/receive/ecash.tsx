import "react-native-get-random-values";
import React, { useState } from 'react';
import { View, StyleSheet, Button } from 'react-native';
import { CameraView, CameraType, useCameraPermissions } from 'expo-camera'; // Update imports
import * as Clipboard from 'expo-clipboard';
import { ClipboardPasteButton } from 'expo-clipboard'; // Add this import
import { Text } from '@/components/nativewindui/Text';
import Drawer from 'expo-router/drawer';
import { NDKCashuWallet } from '@nostr-dev-kit/ndk-wallet';
import { useNDKSession } from "@nostr-dev-kit/ndk-mobile";
import { toast } from "@backpackapp-io/react-native-toast";

export default function ReceiveEcash({ onReceived }: { onReceived: () => void }) {
    const [permission, requestPermission] = useCameraPermissions();
    const { activeWallet } = useNDKWallet();
    const [error, setError] = useState(null);

    if (!permission) {
        return <View />; // Loading state
    }
    if (!permission.granted) {
        return (
            <View style={styles.container}>
                <Text style={styles.message}>We need your permission to show the camera</Text>
                <Button onPress={requestPermission} title="grant permission" />
            </View>
        );
    }

    async function receive(token: string) {
        if (!(activeWallet as NDKCashuWallet)) {
            return;
        }

        (activeWallet as NDKCashuWallet).receiveToken(token)
            .then((result) => {
                console.trace(result);
                onReceived();
            })
            .catch((error) => {
                console.trace(error);
                setError(error.message);
                toast.error('Error receiving token');
            });
    }

    const handleQRCodeScanned = (data: string) => {
        console.log('QR code scanned', data);
        receive(data); // Call send function with scanned data
    };

    return (
        <View style={styles.container}>
            {error && <Text style={styles.error}>{error}</Text>}
            <CameraView 
                 barcodeScannerSettings={{
                    barcodeTypes: ["qr"],
                }}
                style={styles.camera} 
                onBarcodeScanned={({ data }) => handleQRCodeScanned(data)} // Add QR code scan handler
            >
                <View style={styles.buttonContainer} />
            </CameraView>
            {Clipboard.isPasteButtonAvailable && (
                <View style={styles.buttonContainer}>
                  <ClipboardPasteButton 
                      style={[styles.buttonPaste, { width: '100%', height: 50 }]} 
                      onPress={(a) => {
                          if (a.text) receive(a.text)
                      }}
                      displayMode="iconAndLabel" 
                  />
                </View>
            )}
        </View>
    );
};

const styles = StyleSheet.create({
    container: {
      flex: 1,
      alignItems: 'center',
      justifyContent: 'center',
    },
    error: {
        textAlign: 'center',
        paddingBottom: 10,
        color: 'red',
    },
    message: {
      textAlign: 'center',
      paddingBottom: 10,
    },
    camera: {
        borderRadius: 10,
        height: 300,
        width: 300,
      maxHeight: '50%',
    },
    buttonContainer: {
      flexDirection: 'row',
      backgroundColor: 'transparent',
      margin: 20,
    },
    button: {
      flex: 1,
      alignSelf: 'flex-end',
      alignItems: 'center',
    },
    text: {
      fontSize: 24,
      fontWeight: 'bold',
      color: 'white',
    },
    buttonPaste: {
        alignItems: 'center',
        margin: 10,
    },
  });
