import '../global.css';
import 'expo-dev-client';
import '@bacons/text-decoder/install';
import 'react-native-get-random-values';
import { PortalHost } from '@rn-primitives/portal';
import * as SecureStore from 'expo-secure-store';
import { ThemeProvider as NavThemeProvider } from '@react-navigation/native';
import { NDKCacheAdapterSqlite, NDKCashuMintList, NDKEventWithFrom, NDKNutzap, useNDK, useNDKCurrentUser, useNDKNutzapMonitor, useNDKSession, useNDKSessionInit, useNDKWallet } from '@nostr-dev-kit/ndk-mobile';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { KeyboardProvider } from 'react-native-keyboard-controller';

import { useColorScheme, useInitialAndroidBarSync } from '~/lib/useColorScheme';
import { NAV_THEME } from '~/theme';
import { toast, Toasts } from '@backpackapp-io/react-native-toast';
import { NDKKind, NDKList, NDKRelay } from '@nostr-dev-kit/ndk-mobile';
import { NDKCashuWallet, NDKNutzapMonitor } from '@nostr-dev-kit/ndk-wallet';
import { useEffect, useRef, useState } from 'react';
import LoaderScreen from '@/components/LoaderScreen';
import { appReadyAtom } from '@/atoms/app';
import { useSetAtom } from 'jotai';
import { Text } from '@/components/nativewindui/Text';

function NutzapMonitor() {
    const { nutzapMonitor } = useNDKNutzapMonitor();
    const connected = useRef(false);

    if (!nutzapMonitor) return null;
    if (connected.current) {
        console.log('nutzap monitor was already setup');
        return null;
    }

    connected.current = true;

    nutzapMonitor.on("seen", (event) => {
        console.log("seen", JSON.stringify(event.rawEvent(), null, 4));
        console.log(`https://njump.me/${event.encode()}`)
        toast.success("Received a nutzap for " + event.amount + " " + event.unit);
    });
    nutzapMonitor.on("redeem", (event) => {
        const nutzap = NDKNutzap.from(event);
        toast.success("Redeemed a nutzap for " + nutzap.amount + " " + nutzap.unit);
    });
}

const settingsStore = {
    get: SecureStore.getItemAsync,
    set: SecureStore.setItemAsync,
    delete: SecureStore.deleteItemAsync,
    getSync: SecureStore.getItem,
};

const kinds = new Map<NDKKind, { wrapper?: NDKEventWithFrom<any> }>();
kinds.set(NDKKind.CashuMintList, { wrapper: NDKCashuMintList });
kinds.set(NDKKind.CashuWallet, { wrapper: NDKCashuWallet });

export default function RootLayout() {
    useInitialAndroidBarSync();
    const { colorScheme, isDarkColorScheme } = useColorScheme();
    const netDebug = (msg: string, relay: NDKRelay, direction?: 'send' | 'recv') => {
        const url = new URL(relay.url);
        if (direction === 'send') console.log('👉', url.hostname, msg);
        if (direction === 'recv') console.log('👈', url.hostname, msg);
    };

    let relays = (SecureStore.getItem('relays') || '').split(',');

    relays = relays.filter((r) => {
        try {
            return new URL(r).protocol.startsWith('ws');
        } catch (e) {
            return false;
        }
    });

    if (relays.length === 0) {
        relays.push('wss://relay.primal.net');
        relays.push('wss://relay.damus.io');
    }

    relays.push('wss://promenade.fiatjaf.com/');
    relays.push('wss://purplepag.es/');

    const { ndk, init: initializeNDK } = useNDK();
    const currentUser = useNDKCurrentUser();
    const initializeSession = useNDKSessionInit();

    const setAppReady = useSetAtom(appReadyAtom);

    useEffect(() => {
        const currentUserInSettings = SecureStore.getItem('currentUser');

        initializeNDK({
            explicitRelayUrls: relays,
            cacheAdapter: new NDKCacheAdapterSqlite('honeypot'),
            // netDebug,
            clientName: 'honeypot',
            clientNip89: '31990:fa984bd7dbb282f07e16e7ae87b26a2a7b9b90b7246a44771f0cf5ae58018f52:1731850618505',
            settingsStore,
        });

        if (!currentUserInSettings) {
            setAppReady(true);
        }
    }, []);

    useEffect(() => {
        if (!ndk || !currentUser) return;

        console.log('initializeSession');
        initializeSession(ndk, currentUser, settingsStore, {
            muteList: true,
            follows: true,
            kinds,
        }, {
            onReady: () => setAppReady(true)
        });

    }, [ndk, currentUser?.pubkey])
    
    const { activeWallet } = useNDKWallet();

    return (
        <>
            <StatusBar key={`root-status-bar-${isDarkColorScheme ? 'light' : 'dark'}`} style={isDarkColorScheme ? 'light' : 'dark'} />
            {!activeWallet ? (
                <LoaderScreen>
                    <Text>Loading...</Text>
                </LoaderScreen>
            ) : (
                <>
                    <NutzapMonitor />
                    <GestureHandlerRootView style={{ flex: 1 }}>
                        <KeyboardProvider statusBarTranslucent navigationBarTranslucent>
                            <NavThemeProvider value={NAV_THEME[colorScheme]}>
                            <PortalHost />
                            <Stack screenOptions={{
                                headerShown: true,
                            }}>
                                <Stack.Screen name="(awallet)" options={{ headerShown: false, title: 'Wallet' }} />
                                <Stack.Screen name="login" options={{ headerShown: false, presentation: 'modal' }} />
                                <Stack.Screen name="tx" options={{ headerShown: false, presentation: 'modal' }} />
                                <Stack.Screen name="receive" options={{ headerShown: true, presentation: 'modal', title: 'Receive' }} />
                                <Stack.Screen name="send" options={{ headerShown: false, presentation: 'modal', title: 'Send' }} />
                                <Stack.Screen name="beg" options={{ headerShown: false, presentation: 'modal' }} />
                                <Stack.Screen name="(settings)" options={{ headerShown: false, presentation: 'modal' }} />
                            </Stack>
                        </NavThemeProvider>
                        <Toasts />
                        </KeyboardProvider>
                        </GestureHandlerRootView>
                    </>
            )}
        </>
    );
}
