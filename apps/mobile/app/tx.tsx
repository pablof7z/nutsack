import { useActiveEventStore } from "@/stores";
import { ScrollView, View } from "react-native";
import { Text } from "@/components/nativewindui/Text";
import { useEffect, useState } from "react";
import { Hexpubkey, NDKEvent, NDKUser, useNDK } from "@nostr-dev-kit/ndk-mobile";
import { NDKWalletChange } from "@nostr-dev-kit/ndk-wallet";
import { UserAsHeader } from "./send";

export default function TxView() {
    const { currentUser } = useNDK();
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
            {/* <Text>{JSON.stringify(event?.rawEvent(), null, 2)}</Text> */}
        </ScrollView>
    )
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