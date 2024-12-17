import { useColorScheme } from "@/lib/useColorScheme";
import { Tabs } from "expo-router";
import { Bolt, Calendar, List, PieChart, Repeat, SettingsIcon } from "lucide-react-native";
import { View } from "react-native";

export default function Layout({ children }: { children: React.ReactNode }) {
    const { colors } = useColorScheme();
    
    return (
        <Tabs screenOptions={{
            headerShown: true,
            tabBarShowLabel: false,
            tabBarActiveTintColor: colors.foreground,
            tabBarInactiveTintColor: colors.muted,
            tabBarBackground: () => <View className="bg-background" />
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
                name="(settings)"
                options={{
                    title: 'Settings',
                    headerShown: false,
                    tabBarIcon: ({ focused }) => <SettingsIcon size={24} color={focused ? colors.foreground : colors.muted} />
                }}
            />
        </Tabs>
    )
}