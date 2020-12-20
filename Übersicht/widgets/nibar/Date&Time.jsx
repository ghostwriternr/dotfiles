import styles from "./lib/styles.jsx";

const style = {
    background: styles.colors.bg,
    cursor: "default",
    userSelect: "none",
    zIndex: "-1",
    borderRadius: 20,
    width: "calc(100% - 32px)",
    height: "30px",
    position: "fixed",
    overflow: "hidden",
    top: "16px",
    left: "16px",
    flex: 1,
    justifyContent: "center",
    userSelect: "none",
};

export const refreshFrequency = 1000000;

export const render = ({ output }) => {
    return <div style={style} />;
};

export default null;
