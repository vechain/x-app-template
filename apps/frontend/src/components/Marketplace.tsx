import {
  Box,
  Button,
  Card,
  CardBody,
  Grid,
  HStack,
  Heading,
  IconButton,
  Image,
  Input,
  SimpleGrid,
  Text,
  Textarea,
  VStack,
  useToast,
} from '@chakra-ui/react';
import { MarketplaceItem, supabase } from '../networking/supabase';
import { useEffect, useState } from 'react';

import { DeleteIcon } from '@chakra-ui/icons';
import { useDropzone } from 'react-dropzone';
import { useWallet } from '@vechain/dapp-kit-react';

export const Marketplace = () => {
  const [items, setItems] = useState<MarketplaceItem[]>([]);
  const [newItem, setNewItem] = useState({
    title: '',
    description: '',
    price_usd: '',
    image_urls: [] as string[],
  });
  const [uploadingImages, setUploadingImages] = useState(false);
  const { account } = useWallet();
  const toast = useToast();

  const { getRootProps, getInputProps } = useDropzone({
    accept: {
      'image/*': ['.jpeg', '.jpg', '.png', '.webp']
    },
    onDrop: async (acceptedFiles) => {
      setUploadingImages(true);
      try {
        const uploadPromises = acceptedFiles.map(async (file) => {
          const fileExt = file.name.split('.').pop();
          const fileName = `${Math.random()}.${fileExt}`;
          const { error } = await supabase.storage
            .from('marketplace-images')
            .upload(fileName, file);

          if (error) throw error;

          const { data: { publicUrl } } = supabase.storage
            .from('marketplace-images')
            .getPublicUrl(fileName);

          return publicUrl;
        });

        const uploadedUrls = await Promise.all(uploadPromises);
        setNewItem(prev => ({
          ...prev,
          image_urls: [...prev.image_urls, ...uploadedUrls]
        }));
      } catch (error) {
        console.error('Error uploading images:', error);
        toast({
          title: 'Error',
          description: 'Failed to upload images',
          status: 'error',
        });
      } finally {
        setUploadingImages(false);
      }
    }
  });

  useEffect(() => {
    fetchItems();
  }, []);

  const fetchItems = async () => {
    try {
      const { data, error } = await supabase
        .from('marketplace_items')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setItems(data || []);
    } catch (error) {
      console.error('Error fetching items:', error);
      toast({
        title: 'Error',
        description: 'Failed to fetch marketplace items',
        status: 'error',
      });
    }
  };

  const handleCreateItem = async () => {
    if (!account) {
      toast({
        title: 'Error',
        description: 'Please connect your wallet first',
        status: 'error',
      });
      return;
    }

    if (newItem.image_urls.length === 0) {
      toast({
        title: 'Error',
        description: 'Please upload at least one image',
        status: 'error',
      });
      return;
    }

    try {
      const { data, error } = await supabase
        .from('marketplace_items')
        .insert([
          {
            ...newItem,
            price_usd: parseFloat(newItem.price_usd),
            seller_address: account,
            status: 'available',
          },
        ])
        .select();

      if (error) throw error;

      setItems([...(data || []), ...items]);
      setNewItem({
        title: '',
        description: '',
        price_usd: '',
        image_urls: [],
      });

      toast({
        title: 'Success',
        description: 'Item listed successfully',
        status: 'success',
      });
    } catch (error) {
      console.error('Error creating item:', error);
      toast({
        title: 'Error',
        description: 'Failed to create item',
        status: 'error',
      });
    }
  };

  const removeImage = (index: number) => {
    setNewItem(prev => ({
      ...prev,
      image_urls: prev.image_urls.filter((_, i) => i !== index)
    }));
  };

  return (
    <Box p={4}>
      <VStack spacing={8} align="stretch">
        <Heading>Marketplace</Heading>

        {/* Create New Item Form */}
        <Card>
          <CardBody>
            <VStack spacing={4}>
              <Input
                placeholder="Title"
                value={newItem.title}
                onChange={(e) => setNewItem({ ...newItem, title: e.target.value })}
              />
              <Textarea
                placeholder="Description"
                value={newItem.description}
                onChange={(e) => setNewItem({ ...newItem, description: e.target.value })}
              />
              <Input
                type="number"
                placeholder="Price in USD"
                value={newItem.price_usd}
                onChange={(e) => setNewItem({ ...newItem, price_usd: e.target.value })}
              />
              
              {/* Image Upload */}
              <Box
                {...getRootProps()}
                border="2px dashed"
                borderColor="gray.300"
                borderRadius="md"
                p={4}
                textAlign="center"
                cursor="pointer"
                _hover={{ borderColor: 'blue.500' }}
                w="100%"
              >
                <input {...getInputProps()} />
                <Text>
                  {uploadingImages
                    ? 'Uploading...'
                    : 'Drag and drop images here, or click to select files'}
                </Text>
              </Box>

              {/* Preview Uploaded Images */}
              <SimpleGrid columns={3} spacing={4} w="100%">
                {newItem.image_urls.map((url, index) => (
                  <Box key={index} position="relative">
                    <Image
                      src={url}
                      alt={`Uploaded image ${index + 1}`}
                      borderRadius="lg"
                      height="100px"
                      objectFit="cover"
                    />
                    <IconButton
                      aria-label="Remove image"
                      icon={<DeleteIcon />}
                      size="sm"
                      position="absolute"
                      top={2}
                      right={2}
                      onClick={() => removeImage(index)}
                    />
                  </Box>
                ))}
              </SimpleGrid>

              <Button 
                colorScheme="blue" 
                onClick={handleCreateItem}
                isLoading={uploadingImages}
              >
                List Item
              </Button>
            </VStack>
          </CardBody>
        </Card>

        {/* Items Grid */}
        <Grid templateColumns="repeat(auto-fill, minmax(300px, 1fr))" gap={6}>
          {items.map((item) => (
            <Card key={item.id}>
              <CardBody>
                <Image
                  src={item.image_urls[0]}
                  alt={item.title}
                  borderRadius="lg"
                  height="200px"
                  objectFit="cover"
                />
                <VStack align="stretch" mt={4}>
                  <Heading size="md">{item.title}</Heading>
                  <Text>{item.description}</Text>
                  <HStack justify="space-between">
                    <Text fontWeight="bold">${item.price_usd}</Text>
                    <Text color={item.status === 'available' ? 'green.500' : 'red.500'}>
                      {item.status}
                    </Text>
                  </HStack>
                </VStack>
              </CardBody>
            </Card>
          ))}
        </Grid>
      </VStack>
    </Box>
  );
}; 