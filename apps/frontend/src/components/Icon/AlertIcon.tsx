type Props = {
  color: string;
  size: string | number;
};

export const AlertIcon = ({ color, size }: Props) => {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 180 180"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path
        d="M91.3345 116.54H85.9245C81.7658 116.54 78.3945 119.911 78.3945 124.07V129.48C78.3945 133.639 81.7658 137.01 85.9245 137.01H91.3345C95.4932 137.01 98.8645 133.639 98.8645 129.48V124.07C98.8645 119.911 95.4932 116.54 91.3345 116.54Z"
        stroke={color}
        strokeWidth="4.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M79.6645 60.3599L80.3845 95.4099C80.5545 99.3299 84.3645 102.43 89.0145 102.43C93.6545 102.43 97.4645 99.3399 97.6445 95.4299L99.9245 39.0899C100.094 35.2399 98.1045 31.5299 94.6545 29.8099C93.3045 29.1299 91.6445 28.6899 89.6445 28.6899C82.0645 28.6899 79.0845 35.9199 79.0845 35.9199L30.0245 135.46C26.3345 142.94 31.7845 151.69 40.1245 151.69H139.174C147.514 151.69 152.955 142.94 149.275 135.46L117.064 70.0999"
        stroke={color}
        strokeWidth="4.5"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
};
