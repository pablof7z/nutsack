import { View } from "react-native";
import { Text } from "@/components/nativewindui/Text";
import { Button } from "@/components/nativewindui/Button";
import { CalendarClock } from "lucide-react-native";
import { List, ListItem } from "@/components/nativewindui/List";
import { useColorScheme } from "@/lib/useColorScheme";
import { NDKEvent, NDKKind, useNDK, useSubscribe, useUserProfile } from "@nostr-dev-kit/ndk-mobile";
import { useMemo } from "react";
import * as User from "@/components/ui/user";
import { useSafeAreaInsets } from "react-native-safe-area-context";

function SubscriptionItem({ event, index, target }: { event: NDKEvent, index: number, target: ListTarget }) {
    const profile = useUserProfile(event.pubkey);

    if (!profile) return null;
    
    return (
        <ListItem
            leftView={
                <User.Avatar
                    userProfile={profile.userProfile}
                    size={48}
                    className="w-6 h-6 mr-2"
                />
            }
            item={{
                id: event.id,
            }}
            index={index}
            target={target}
        >
            <User.Name userProfile={profile.userProfile} pubkey={event.pubkey} className="text-foreground" />
        </ListItem>
    )
}

export default function Subscriptions() {
    const { colors } = useColorScheme();
    const filters = useMemo(() => ([
        { kinds: [NDKKind.TierList] }
    ]), []);
    const {events} = useSubscribe({filters});
    const insets = useSafeAreaInsets();
    
    return (
        <View className="flex-1 items-stretch p-4 bg-card" style={{ paddingTop: insets.top }}>
            <View className="flex-col gap-1 items-start justify-start text-left w-full">
                <Text className="text-xl font-bold text-left">Subscriptions</Text>
                <Text className="text-muted-foreground">
                    These are your currently active subscriptions.
                </Text>
            </View>

            <View className="flex-1 items-center justify-center gap-4">
                <CalendarClock size={64} color={colors.foreground} />
                
                <Text className="text-muted-foreground mt-5">
                    You don't have any subscriptions yet.
                </Text>

                <Button variant="default">
                    <Text className="px-6">
                        Explore
                    </Text>
                </Button>

                <Text className="text-muted-foreground text-sm">
                    Browse services and projects to support
                </Text>

                
            </View>
{/* 
            <List
                data={events}
                keyExtractor={(item) => item.id}
                renderItem={({ item, index, target }) => (
                    <SubscriptionItem event={item} index={index} target={target} />
                )}
            /> */}
        </View>
    )
}