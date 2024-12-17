import { useColorScheme } from "@/lib/useColorScheme";
import { useNDK, useNDKSession } from "@nostr-dev-kit/ndk-mobile";
import { BlurView } from "expo-blur";
import { Redirect, Tabs } from "expo-router";
import { Bolt, Calendar, List, PieChart, Repeat, SettingsIcon } from "lucide-react-native";
import { View } from "react-native";

export default function Layout({ children }: { children: React.ReactNode }) {
    const { colors } = useColorScheme();
    const { currentUser } = useNDK();
    const { activeWallet } = useNDKSession();

    if (!currentUser) {
        return <Redirect href="/login" />
    }

    if (!activeWallet) {
        return <Redirect href="/(settings)/wallets" />
    }
    
    return (
        <Tabs screenOptions={{
            headerShown: true,
            tabBarShowLabel: true,
            tabBarActiveTintColor: colors.foreground,
        }}>
            <Tabs.Screen
                name="index"
                options={{
                    title: 'Wallet',
                    headerShown: false,
                    tabBarIcon: ({ focused }) => <Bolt size={24} color={focused ? colors.foreground : colors.muted} />
                }}
            />

            <Tabs.Screen
                name="mint"
                options={{
                    title: 'Mints',
                    headerShown: false,
                    tabBarIcon: ({ focused }) => <PieChart size={24} color={focused ? colors.foreground : colors.muted} />
                }}
            />

            <Tabs.Screen
                name="subscriptions"
                options={{
                    title: 'Subscriptions',
                    headerShown: false,
                    tabBarIcon: ({ focused }) => <Calendar size={24} color={focused ? colors.foreground : colors.muted} />
                }}
            />
            
            <Tabs.Screen
                name="(walletSettings)"
                options={{
                    title: 'Settings',
                    headerShown: false,
                    tabBarIcon: ({ focused }) => <SettingsIcon size={24} color={focused ? colors.foreground : colors.muted} />
                }}
            />
        </Tabs>
    )
}