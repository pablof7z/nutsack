import { useActiveEventStore } from "@/stores";
import { ScrollView, View } from "react-native";
import { Text } from "@/components/nativewindui/Text";
import { useEffect, useState } from "react";
import { Hexpubkey, NDKEvent, NDKTag, NDKUser, useNDK, useNDKCurrentUser } from "@nostr-dev-kit/ndk-mobile";
import { NDKWalletChange } from "@nostr-dev-kit/ndk-wallet";
import { UserAsHeader } from "./send";

export default function TxView() {
    const currentUser = useNDKCurrentUser();
    const { activeEvent } = useActiveEventStore();
    const [event, setEvent] = useState<NDKEvent | null>(null);
    const [counterPart, setCounterPart] = useState<Hexpubkey | undefined>(undefined);
    const [records, setRecords] = useState<Record<string, string>>({});

    useEffect(() => {
        NDKWalletChange.from(activeEvent).then((e) => {
            setEvent(e);

            const counterpart = getCounterPart(e, currentUser);
            if (counterpart) {
                setCounterPart(counterpart);
            }

            setRecords(getRecords(e));
        });
    }, []);

    if (!event) return null;
    
    return (
        <ScrollView className="flex-1 p-4 gap-10 flex-col">
            {counterPart && <UserAsHeader pubkey={counterPart} />}
            <View>
                {Object.entries(records).map(([key, value]) => (
                    <View key={key} className="flex-row gap-2">
                        <Text className="font-mono font-bold w-1/3">{key}: </Text>
                        <Text className="font-mono w-2/3">{value}</Text>
                    </View>
                ))}
            </View>

            {event.getMatchingTags('e').map((tag, index) => (
                <TaggedEvent key={index} originalEvent={event} tag={tag} index={index} />
            ))}
            
            {/* <Text>{JSON.stringify(event?.rawEvent(), null, 2)}</Text> */}
        </ScrollView>
    )
}

function TaggedEvent({ originalEvent, tag, index }: { originalEvent: NDKEvent, tag: NDKTag, index: number }) {
    const { ndk } = useNDK();
    const [taggedEvent, setTaggedEvent] = useState<NDKEvent | null>(null);
    const marker = tag[3];
    
    if (marker === 'created') {
        return <View className="flex-col gap-2">
            <Text className="font-mono font-bold">Created: </Text>
            <Text className="font-mono">{tag[1]}</Text>
        </View>
    }

    useEffect(() => {
        const fetch = tag[1];
        
        ndk.fetchEventFromTag(tag, originalEvent)
            .then((e) => {
                if (e.tagId() !== fetch) {
                    console.log('we avoided rendering a wrong event', { fetch, tagId: e.tagId()});
                    return;
                }

                setTaggedEvent(e);
            });
    }, [originalEvent, index]);

    if (!taggedEvent) return null;

    if (marker === 'redeemed') {
        return <View className="flex-col gap-2">
            <Text className="font-mono font-bold">Redeemed: </Text>
            <Text className="font-mono">{taggedEvent.id}</Text>
            <Text className="bg-card p-4 rounded-xl text-lg font-bold font-sans">{taggedEvent.content}</Text>
        </View>
    }

    return <View className="flex-col gap-2">
        {marker && <Text className="font-mono font-bold">{marker}: </Text>}
        <Text className="font-mono">{JSON.stringify(taggedEvent.rawEvent(), null, 2)}</Text>
    </View>
}

function getCounterPart(event: NDKWalletChange, currentUser: NDKUser): Hexpubkey | undefined {
    const pTags = event.getMatchingTags('p');

    return pTags.find((tag) => tag[1] !== currentUser.pubkey)?.[1];
}

function getRecords(event: NDKWalletChange): Record<string, string> {
    const res = {};

    for (const tag of event.tags) {
        if (tag[0].length > 1) {
            res[tag[0]] = tag[1];
        }
    }
    
    return res;
}