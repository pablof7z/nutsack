import { useCallback } from 'react';
import { NDKEvent, NDKPrivateKeySigner, NDKRelaySet, useNDK } from '@nostr-dev-kit/ndk-mobile';
import { useActiveBlossomServer } from './blossom';
import { useAtom, useSetAtom } from 'jotai';
import { metadataAtom, selectedMediaAtom, stepAtom, uploadingAtom } from '@/components/NewPost/store';
import { prepareMedia } from '@/components/NewPost/prepare';
import { uploadMedia } from '@/components/NewPost/upload';
import * as ImagePicker from 'expo-image-picker';
import { toast } from '@backpackapp-io/react-native-toast';
import { router } from 'expo-router';
import { useAppSettingsStore } from '@/stores/app';
import { mapAssetToMediaLibraryItem } from '@/utils/media';

type NewPostProps = {
    types: ('images' | 'videos')[];
    
    /**
     * Whether to force a 1:1 aspect ratio
     */
    square?: boolean;
}

export function useNewPost() {
    const { ndk } = useNDK();
    const activeBlossomServer = useActiveBlossomServer();
    const setUploading = useSetAtom(uploadingAtom);
    const [step, setStep] = useAtom(stepAtom);
    const setSelectedMedia = useSetAtom(selectedMediaAtom);
    const { postType, removeLocation } = useAppSettingsStore();
    const [metadata, setMetadata] = useAtom(metadataAtom);

    const launchImagePicker = useCallback(({types, square} : NewPostProps) => {
        // reset metadata
        setMetadata({ ...metadata, caption: '', type: 'high-quality', removeLocation });

        ImagePicker.launchImageLibraryAsync({
            mediaTypes: types,
            allowsMultipleSelection: true,
            selectionLimit: 6,
            allowsEditing: !!square,
            aspect: square ? [1, 1] : undefined,
            exif: true,
        }).then((result) => {
            if (result.assets) {
                Promise.all(result.assets.map(mapAssetToMediaLibraryItem)).then((sel) => {
                    setSelectedMedia(sel);
                    setStep(step + 1);
                    setUploading(true);
                    router.push('/publish');
                    return new Promise<void>(async (resolve) => {
                        try {
                            const preparedMedia = await prepareMedia(sel);

                            const uploadedMedia = await uploadMedia(preparedMedia, ndk, activeBlossomServer);
                            setSelectedMedia(uploadedMedia);
                            setUploading(false);
                        } catch (error) {
                            console.error('Error uploading media', error);
                            toast.error('Error uploading media: ' + error.message);
                        } finally {
                            resolve();
                        }
                    });
                });
            }
        });
    }, [ndk, activeBlossomServer, postType, removeLocation]);

    return launchImagePicker;
}
