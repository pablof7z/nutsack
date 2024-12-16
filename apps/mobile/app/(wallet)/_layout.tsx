import { useColorScheme } from "@/lib/useColorScheme";
import { Tabs } from "expo-router";
import { List, PieChart, SettingsIcon } from "lucide-react-native";
import { View } from "react-native";

export default function Layout({ children }: { children: React.ReactNode }) {
    const { colors } = useColorScheme();
    
    return (
        <Tabs screenOptions={{
            headerShown: false,
            tabBarShowLabel: false,
            tabBarActiveTintColor: colors.foreground,
            tabBarInactiveTintColor: colors.muted,
            tabBarBackground: () => <View className="bg-background" />
        }}>
            <Tabs.Screen
                name="index"
                options={{
                    title: 'Wallet',
                    headerShown: true,
                    tabBarIcon: ({ focused }) => <PieChart size={24} color={focused ? colors.foreground : colors.muted} />
                }}
            />
            <Tabs.Screen
                name="tokens"
                options={{
                    title: 'Tokens',
                    headerShown: true,
                    tabBarIcon: ({ focused }) => <List size={24} color={focused ? colors.foreground : colors.muted} />
                }}
            />
            <Tabs.Screen
                name="(settings)"
                options={{
                    title: 'Settings',
                    headerShown: true,
                    tabBarIcon: ({ focused }) => <SettingsIcon size={24} color={focused ? colors.foreground : colors.muted} />
                }}
            />
        </Tabs>
    )
}