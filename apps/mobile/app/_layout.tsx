import '../global.css';
import 'expo-dev-client';
import '@bacons/text-decoder/install';
import 'react-native-get-random-values';
import { PortalHost } from '@rn-primitives/portal';
import * as SecureStore from 'expo-secure-store';
import { Image } from 'react-native';
import { ThemeProvider as NavThemeProvider } from '@react-navigation/native';
import { NDKCacheAdapterSqlite, NDKCashuMintList, NDKEventWithFrom, NDKNutzap, useNDK, useNDKSession } from '@nostr-dev-kit/ndk-mobile';
import { router, Stack } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { StatusBar } from 'expo-status-bar';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { KeyboardProvider } from 'react-native-keyboard-controller';
import { View } from 'react-native';

import { useColorScheme, useInitialAndroidBarSync } from '~/lib/useColorScheme';
import { NAV_THEME } from '~/theme';
import { NDKProvider } from '@nostr-dev-kit/ndk-mobile';
import { toast, Toasts } from '@backpackapp-io/react-native-toast';
import { Text } from '@/components/nativewindui/Text';
import { NDKKind, NDKList, NDKRelay } from '@nostr-dev-kit/ndk-mobile';
import { NDKSessionProvider } from '@nostr-dev-kit/ndk-mobile';
import { ActivityIndicator } from '@/components/nativewindui/ActivityIndicator';
import { NDKCashuWallet, NDKNutzapMonitor } from '@nostr-dev-kit/ndk-wallet';
import { useEffect, useRef, useState } from 'react';
import { Button } from '@/components/nativewindui/Button';

function Container({ children }: { children: React.ReactNode }) {
    const splashImage = require('../assets/splash.png');

    return (
        <View className="flex bg-black flex-col relative h-screen w-screen items-stretch">
            <Image source={splashImage} className="h-screen w-screen absolute top-0 left-0"/>

            <View className="flex flex-col absolute bottom-10 left-10 z-10 right-10 items-center">
                {children}
            </View>
        </View>
    );
}

function NDKCacheCheck({ children }: { children: React.ReactNode }) {
    const { ndk, currentUser, cacheInitialized } = useNDK();
    const { activeWallet } = useNDKSession();
    const [ ready, setReady ] = useState(false);

    const start = () => {
        setReady(true);
    }

    useEffect(() => {
        if (cacheInitialized && currentUser && activeWallet) {
            setTimeout(() => setReady(true), 500);
        }

        if (!currentUser && ready) {
            setReady(false);
        }
    }, [cacheInitialized, currentUser, activeWallet]);

    if (!ready) {
        if (cacheInitialized === false) {
            return (
                <Container>
                    <ActivityIndicator className="mt-4" color="white" />
                </Container>
            );
        } else if (!currentUser) {
            return (
                <Container>
                    <Button variant="accent" className="mt-4 w-full" onPress={start}>
                        <Text className="text-white font-semibold">
                            Get Started
                        </Text>
                    </Button>
                </Container>
            )
        } else if (!activeWallet) {
            return (
                <Container>
                    <Button variant="accent" className="mt-4 w-full" onPress={() => {
                        setReady(true);
                    }}>
                        <Text className="text-white font-semibold">
                            Enable Wallet
                        </Text>
                    </Button>
                </Container>
            )
        } else {
            return (
                <Container>
                    <Text className="text-white font-semibold">
                        Everything ready - LFG
                    </Text>
                </Container>
            )
        }
    } else {
        return <>{children}</>;
    }
}

export default function RootLayout() {
    useInitialAndroidBarSync();
    const { colorScheme, isDarkColorScheme } = useColorScheme();
    const netDebug = (msg: string, relay: NDKRelay, direction?: 'send' | 'recv') => {
        const url = new URL(relay.url);
        if (direction === 'send') console.log('👉', url.hostname, msg);
        // if (direction === 'recv') console.log('👈', url.hostname, msg);
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

    const { ndk, currentUser } = useNDK();
    const nutzapMonitor = useRef<NDKNutzapMonitor | null>(null);

    useEffect(() => {
        if (!ndk || !currentUser || nutzapMonitor.current) return;
        const mon = new NDKNutzapMonitor(ndk, currentUser);
        mon.on("seen", (event) => {
            console.log("seen", JSON.stringify(event.rawEvent(), null, 4));
            console.log(`https://njump.me/${event.encode()}`)
        });
        mon.on("redeem", (event) => {
            const nutzap = NDKNutzap.from(event);
            toast.success("Redeemed a nutzap for " + nutzap.amount + " " + nutzap.unit);
        });
        mon.start();
        nutzapMonitor.current = mon;
    }, [ndk, currentUser]);

    const kinds = new Map<NDKKind, { wrapper?: NDKEventWithFrom<any> }>();
    kinds.set(NDKKind.CashuMintList, { wrapper: NDKCashuMintList });
    kinds.set(NDKKind.CashuWallet, { wrapper: NDKCashuWallet });

    return (
        <>
            <StatusBar key={`root-status-bar-${isDarkColorScheme ? 'light' : 'dark'}`} style={isDarkColorScheme ? 'light' : 'dark'} />
            <NDKProvider
                explicitRelayUrls={relays}
                cacheAdapter={new NDKCacheAdapterSqlite('honeypot')}
                netDebug={netDebug}
                clientName="honeypot"
                clientNip89="31990:fa984bd7dbb282f07e16e7ae87b26a2a7b9b90b7246a44771f0cf5ae58018f52:1731850618505"
            >
                <NDKSessionProvider
                    muteList={true}
                    follows={true}
                    wallet={true}
                    settingsStore={{
                        get: SecureStore.getItemAsync,
                        set: SecureStore.setItemAsync,
                        delete: SecureStore.deleteItemAsync,
                    }}
                    kinds={kinds}
                >
                    <NDKCacheCheck>
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
                                        <Stack.Screen name="send" options={{ headerShown: true, presentation: 'modal', title: 'Send' }} />
                                        <Stack.Screen name="beg" options={{ headerShown: false, presentation: 'modal' }} />
                                        <Stack.Screen name="(settings)" options={{ headerShown: false, presentation: 'modal' }} />
                                    </Stack>
                                </NavThemeProvider>
                                <Toasts />
                            </KeyboardProvider>
                        </GestureHandlerRootView>
                    </NDKCacheCheck>
                </NDKSessionProvider>
            </NDKProvider>
        </>
    );
}
