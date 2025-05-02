import {
  Accordion,
  AccordionButton,
  AccordionIcon,
  AccordionItem,
  AccordionPanel,
  Box,
  Button,
  Card,
  CardBody,
  Flex,
  HStack,
  Heading,
  IconButton,
  Image,
  Input,
  Modal,
  ModalBody,
  ModalCloseButton,
  ModalContent,
  ModalOverlay,
  SimpleGrid,
  Text,
  Textarea,
  VStack,
  useDisclosure,
  useToast,
} from '@chakra-ui/react';
import { ChevronLeftIcon, ChevronRightIcon, DeleteIcon, EditIcon } from '@chakra-ui/icons';
import { MarketplaceItem, supabase } from '../networking/supabase';
import { useEffect, useState } from 'react';

import { useDropzone } from 'react-dropzone';
import { useWallet } from '@vechain/dapp-kit-react';

const ImageCarousel = ({ images, onImageClick }: { images: string[], onImageClick: (index: number) => void }) => {
  const [currentIndex, setCurrentIndex] = useState(0);

  const nextImage = () => {
    setCurrentIndex((prev) => (prev + 1) % images.length);
  };

  const prevImage = () => {
    setCurrentIndex((prev) => (prev - 1 + images.length) % images.length);
  };

  return (
    <Box position="relative" width="100%" height="200px">
      <Image
        src={images[currentIndex]}
        alt={`Image ${currentIndex + 1}`}
        width="100%"
        height="100%"
        objectFit="cover"
        borderRadius="lg"
        cursor="pointer"
        onClick={() => onImageClick(currentIndex)}
      />
      {images.length > 1 && (
        <>
          <IconButton
            aria-label="Previous image"
            icon={<ChevronLeftIcon />}
            position="absolute"
            left={2}
            top="50%"
            transform="translateY(-50%)"
            onClick={(e) => {
              e.stopPropagation();
              prevImage();
            }}
            size="sm"
            borderRadius="full"
          />
          <IconButton
            aria-label="Next image"
            icon={<ChevronRightIcon />}
            position="absolute"
            right={2}
            top="50%"
            transform="translateY(-50%)"
            onClick={(e) => {
              e.stopPropagation();
              nextImage();
            }}
            size="sm"
            borderRadius="full"
          />
          <HStack
            position="absolute"
            bottom={2}
            left="50%"
            transform="translateX(-50%)"
            spacing={1}
          >
            {images.map((_, index) => (
              <Box
                key={index}
                w={2}
                h={2}
                borderRadius="full"
                bg={index === currentIndex ? 'blue.500' : 'whiteAlpha.700'}
                onClick={(e) => {
                  e.stopPropagation();
                  setCurrentIndex(index);
                }}
                cursor="pointer"
              />
            ))}
          </HStack>
        </>
      )}
    </Box>
  );
};

const ImageModal = ({ isOpen, onClose, images, initialIndex }: { 
  isOpen: boolean, 
  onClose: () => void, 
  images: string[],
  initialIndex: number 
}) => {
  const [currentIndex, setCurrentIndex] = useState(initialIndex);

  const nextImage = () => {
    setCurrentIndex((prev) => (prev + 1) % images.length);
  };

  const prevImage = () => {
    setCurrentIndex((prev) => (prev - 1 + images.length) % images.length);
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} size="xl">
      <ModalOverlay />
      <ModalContent>
        <ModalCloseButton />
        <ModalBody p={4}>
          <Flex direction="column" align="center">
            <Image
              src={images[currentIndex]}
              alt={`Image ${currentIndex + 1}`}
              maxH="70vh"
              objectFit="contain"
            />
            {images.length > 1 && (
              <HStack mt={4} spacing={4}>
                <IconButton
                  aria-label="Previous image"
                  icon={<ChevronLeftIcon />}
                  onClick={prevImage}
                />
                <Text>{currentIndex + 1} / {images.length}</Text>
                <IconButton
                  aria-label="Next image"
                  icon={<ChevronRightIcon />}
                  onClick={nextImage}
                />
              </HStack>
            )}
          </Flex>
        </ModalBody>
      </ModalContent>
    </Modal>
  );
};

export const Marketplace = () => {
  const [items, setItems] = useState<MarketplaceItem[]>([]);
  const [newItem, setNewItem] = useState({
    title: '',
    description: '',
    price_usd: '',
    image_urls: [] as string[],
    contact_email: '',
    contact_phone: '',
  });
  const [editingItem, setEditingItem] = useState<MarketplaceItem | null>(null);
  const [uploadingImages, setUploadingImages] = useState(false);
  const { account } = useWallet();
  const toast = useToast();
  const { isOpen, onOpen, onClose } = useDisclosure();
  const [selectedItem, setSelectedItem] = useState<{ images: string[], index: number } | null>(null);

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
            contact_email: newItem.contact_email || null,
            contact_phone: newItem.contact_phone || null,
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
        contact_email: '',
        contact_phone: '',
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

  const handleImageClick = (item: MarketplaceItem, index: number) => {
    setSelectedItem({ images: item.image_urls, index });
    onOpen();
  };

  const handleEditItem = async (item: MarketplaceItem) => {
    if (!account) {
      toast({
        title: 'Error',
        description: 'Please connect your wallet first',
        status: 'error',
      });
      return;
    }

    try {
      const { data, error } = await supabase
        .from('marketplace_items')
        .update({
          title: editingItem?.title,
          description: editingItem?.description,
          price_usd: parseFloat(editingItem?.price_usd || '0'),
          contact_email: editingItem?.contact_email || null,
          contact_phone: editingItem?.contact_phone || null,
        })
        .eq('id', editingItem?.id)
        .select();

      if (error) throw error;

      setItems(items.map(item => 
        item.id === editingItem?.id ? data[0] : item
      ));
      setEditingItem(null);

      toast({
        title: 'Success',
        description: 'Item updated successfully',
        status: 'success',
      });
    } catch (error) {
      console.error('Error updating item:', error);
      toast({
        title: 'Error',
        description: 'Failed to update item',
        status: 'error',
      });
    }
  };

  return (
    <Box p={4}>
      <VStack spacing={8} align="stretch">
        <Heading>Marketplace</Heading>

        {/* Create New Item Form */}
        <Accordion allowToggle>
          <AccordionItem>
            <AccordionButton>
              <Box flex="1" textAlign="left">
                <Heading size="md">List New Item</Heading>
              </Box>
              <AccordionIcon />
            </AccordionButton>
            <AccordionPanel pb={4}>
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
                    <Input
                      type="email"
                      placeholder="Contact Email (optional)"
                      value={newItem.contact_email}
                      onChange={(e) => setNewItem({ ...newItem, contact_email: e.target.value })}
                    />
                    <Input
                      type="tel"
                      placeholder="Contact Phone (optional)"
                      value={newItem.contact_phone}
                      onChange={(e) => setNewItem({ ...newItem, contact_phone: e.target.value })}
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
            </AccordionPanel>
          </AccordionItem>
        </Accordion>

        {/* Items Grid */}
        <Flex wrap="wrap" gap={6}>
          {items.map((item) => (
            <Card key={item.id} flex="1" minW="300px" maxW="400px">
              <CardBody>
                <ImageCarousel 
                  images={item.image_urls} 
                  onImageClick={(index) => handleImageClick(item, index)} 
                />
                <VStack align="stretch" mt={4}>
                  {editingItem?.id === item.id ? (
                    <>
                      <Input
                        value={editingItem.title}
                        onChange={(e) => setEditingItem({ ...editingItem, title: e.target.value })}
                      />
                      <Textarea
                        value={editingItem.description}
                        onChange={(e) => setEditingItem({ ...editingItem, description: e.target.value })}
                      />
                      <Input
                        type="number"
                        value={editingItem.price_usd}
                        onChange={(e) => setEditingItem({ ...editingItem, price_usd: e.target.value })}
                      />
                      <Input
                        type="email"
                        value={editingItem.contact_email || ''}
                        onChange={(e) => setEditingItem({ ...editingItem, contact_email: e.target.value })}
                      />
                      <Input
                        type="tel"
                        value={editingItem.contact_phone || ''}
                        onChange={(e) => setEditingItem({ ...editingItem, contact_phone: e.target.value })}
                      />
                      <HStack>
                        <Button colorScheme="blue" onClick={() => handleEditItem(item)}>
                          Save
                        </Button>
                        <Button onClick={() => setEditingItem(null)}>
                          Cancel
                        </Button>
                      </HStack>
                    </>
                  ) : (
                    <>
                      <Heading size="md">{item.title}</Heading>
                      <Text>{item.description}</Text>
                      <HStack justify="space-between">
                        <Text fontWeight="bold">${item.price_usd}</Text>
                        <Text color={item.status === 'available' ? 'green.500' : 'red.500'}>
                          {item.status}
                        </Text>
                      </HStack>
                      {(item.contact_email || item.contact_phone) && (
                        <Box mt={2}>
                          <Text fontSize="sm" color="gray.500">Contact:</Text>
                          {item.contact_email && (
                            <Text fontSize="sm">
                              <a href={`mailto:${item.contact_email}`}>{item.contact_email}</a>
                            </Text>
                          )}
                          {item.contact_phone && (
                            <Text fontSize="sm">
                              <a href={`tel:${item.contact_phone}`}>{item.contact_phone}</a>
                            </Text>
                          )}
                        </Box>
                      )}
                      {account === item.seller_address && (
                        <IconButton
                          aria-label="Edit item"
                          icon={<EditIcon />}
                          onClick={() => setEditingItem(item)}
                          size="sm"
                          alignSelf="flex-end"
                        />
                      )}
                    </>
                  )}
                </VStack>
              </CardBody>
            </Card>
          ))}
        </Flex>
      </VStack>

      {/* Image Modal */}
      {selectedItem && (
        <ImageModal
          isOpen={isOpen}
          onClose={onClose}
          images={selectedItem.images}
          initialIndex={selectedItem.index}
        />
      )}
    </Box>
  );
}; 