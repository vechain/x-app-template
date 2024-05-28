import { Box, HStack, Image, VStack, Text } from "@chakra-ui/react";

type Props = {
  icon: string;
  title: string;
  description: string;
};

export const Step = ({ icon, title, description }: Props) => {
  return (
    <Box mx={{ base: 0, md: 4 }} my={{ base: 2, md: 0 }}>
      <HStack>
        <Image src={icon} w={{ base: 20, md: 36 }} />
        <VStack align={"flex-start"}>
          <Text fontSize={{ base: "14", md: "20" }} fontWeight={700}>
            {title}
          </Text>
          <Text
            fontSize={{ base: "12", md: "16" }}
            fontWeight={400}
            color={"gray.500"}
          >
            {description}
          </Text>
        </VStack>
      </HStack>
    </Box>
  );
};
