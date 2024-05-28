"use client";
import {
  VStack,
  Text,
  Container,
  HStack,
  Box,
  Show,
  Link,
  Flex,
} from "@chakra-ui/react";

import { DiscordButton } from "./components/DiscordButton";
import { TelegramButton } from "./components/TelegramButton";
import { Socials } from "./components/Socials";
import { PRIVACY_POLICY_LINK, TERMS_AND_CONDITIONS_LINK } from "../../const";
import { BeBetterVeBetterIcon } from "../Icon";

export const Footer: React.FC = () => {
  const desktopContent = (
    <VStack>
      <HStack justifyContent={"space-between"} w="full" spacing={4} my={4}>
        <Box my={14}>
          <BeBetterVeBetterIcon
            beBetterProps={{
              width: "80%",
            }}
            veBetterProps={{
              width: "100%",
            }}
          />
        </Box>
        <VStack spacing={4} alignItems={"flex-end"}>
          <DiscordButton />
          <TelegramButton />
        </VStack>
      </HStack>
      <HStack
        justifyContent={"space-between"}
        w="full"
        borderTopColor={"#3e3c3a"}
        borderTopWidth={1}
        py={8}
      >
        <Text
          fontWeight={400}
          fontSize="14px"
          lineHeight="17px"
          color="#8c8c8c"
        >
          2024 VeBetterDAO. All rights reserved.
        </Text>
        <HStack spacing={4}>
          <Link href={PRIVACY_POLICY_LINK} isExternal>
            <Text
              fontWeight={400}
              fontSize="14px"
              lineHeight="17px"
              color="#8c8c8c"
              as="u"
              cursor={"pointer"}
            >
              Privacy & Policy
            </Text>
          </Link>
          <Link href={TERMS_AND_CONDITIONS_LINK} isExternal>
            <Text
              fontWeight={400}
              fontSize="14px"
              lineHeight="17px"
              color="#8c8c8c"
              as="u"
              cursor={"pointer"}
            >
              Terms & Conditions
            </Text>
          </Link>
        </HStack>
        <Socials />
      </HStack>
    </VStack>
  );

  const mobileContent = (
    <VStack>
      <VStack spacing={4} my={4}>
        <Box my={8}>
          <BeBetterVeBetterIcon
            beBetterProps={{
              width: "80%",
            }}
            veBetterProps={{
              width: "100%",
            }}
          />
        </Box>
        <VStack spacing={4} alignItems={"center"}>
          <DiscordButton />
          <TelegramButton />
          <Box mt={6}>
            <Socials />
          </Box>
        </VStack>
      </VStack>
      <VStack borderTopColor={"#3e3c3a"} borderTopWidth={1} py={8}>
        <Link href={PRIVACY_POLICY_LINK} isExternal>
          <Text
            fontWeight={400}
            fontSize="14px"
            lineHeight="17px"
            color="#8c8c8c"
            as="u"
            cursor={"pointer"}
          >
            Privacy & Policy
          </Text>
        </Link>
        <Link href={TERMS_AND_CONDITIONS_LINK} isExternal>
          <Text
            fontWeight={400}
            fontSize="14px"
            lineHeight="17px"
            color="#8c8c8c"
            as="u"
            cursor={"pointer"}
          >
            Terms & Conditions
          </Text>
        </Link>
        <Text
          fontWeight={400}
          fontSize="14px"
          lineHeight="17px"
          color="#8c8c8c"
          mt={6}
        >
          2024 VeBetterDAO. All rights reserved.
        </Text>
      </VStack>
    </VStack>
  );

  return (
    <Flex bgColor={"#191714"}>
      <Container
        maxW={"container.xl"}
        display={"flex"}
        alignItems={"stretch"}
        justifyContent={"flex-start"}
        flexDirection={"column"}
      >
        <Show above="md">{desktopContent}</Show>
        <Show below="md">{mobileContent}</Show>
      </Container>
    </Flex>
  );
};
