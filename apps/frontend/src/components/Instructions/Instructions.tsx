import { Card, Flex } from "@chakra-ui/react";
import { Step } from "./Step";

const Steps = [
  {
    icon: "/steps/1.svg",
    title: "Purchase eco-friendly products",
    description: "Buy products that are eco-friendly and sustainable.",
  },
  {
    icon: "/steps/2.svg",
    title: "Upload the receipt",
    description: "Upload your receipt and AI will verify the products.",
  },
  {
    icon: "/steps/3.svg",
    title: "Earn rewards",
    description: "Earn B3TR for purchasing eco-friendly products.",
  },
];

export const Instructions = () => {
  return (
    <Card mt={3} w={"full"}>
      <Flex p={{ base: 4 }} w="100%" direction={{ base: "column", md: "row" }}>
        {Steps.map((step, index) => (
          <Step key={index} {...step} />
        ))}
      </Flex>
    </Card>
  );
};
