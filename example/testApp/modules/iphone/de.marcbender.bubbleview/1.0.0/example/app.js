/**
 * TiBubble Module - Comprehensive Demo
 * 
 * Demonstrates all features of the TiBubble module:
 * - Bubble creation with all properties
 * - Runtime property changes
 * - Child views (labels, buttons)
 * - Event handling (click, touch)
 * - Animations
 * - Multiple bubble configurations
 * 
 * Created by Marc Bender
 * Copyright (c) 2026 TiDev, Inc. All rights reserved.
 */

const tibubble = require('de.marcbender.bubbleview');

Ti.API.info('========================================');
Ti.API.info('TiBubble Module Demo');
Ti.API.info('========================================');

// Main window
const win = Ti.UI.createWindow({
    backgroundColor: '#f5f5f5',
    title: 'TiBubble Demo'
});

// Navigation bar
const navBar = Ti.UI.createView({
    backgroundColor: '#2c3e50',
    top: 0,
    left: 0,
    right: 0,
    height: 50
});

const navLabel = Ti.UI.createLabel({
    text: 'TiBubble Demo',
    color: '#ffffff',
    font: { fontSize: 20, fontWeight: 'bold' },
    height: Ti.SIZE_AUTO,
    width: Ti.SIZE_AUTO,
    textAlign: 'center',
    top: 8
});
navBar.add(navLabel);
win.add(navBar);

// Status label
const statusLabel = Ti.UI.createLabel({
    text: 'Tap buttons to change bubble properties',
    color: '#7f8c8d',
    font: { fontSize: 12 },
    height: Ti.SIZE_AUTO,
    width: Ti.UI.SIZE,
    textAlign: 'center',
    top: 55
});
win.add(statusLabel);

// ========================================
// Section 1: Main Bubble with Text
// ========================================
const section1Label = Ti.UI.createLabel({
    text: 'Main Bubble',
    color: '#2c3e50',
    font: { fontSize: 16, fontWeight: 'bold' },
    top: 75,
    left: 10
});
win.add(section1Label);

const mainBubble = tibubble.createBubble({
    bubbleColor: '#3498db',
    bubbleRadius: 25,
    bubbleBeak: tibubble.BUBBLE_BEAK_LEFT,
    bubbleBeakVertical: tibubble.BUBBLE_BEAK_LOWER,
    tailWidth: 8,       // Width of the tail base (dp)
    tailLength: 12,     // Length of the tail tip (dp)
    tailCurveY: 8,      // Curve intensity of the tail (dp)
    width: 200,
    height: 120,
    top: 95,
    left: 20
});

const mainLabel = Ti.UI.createLabel({
    text: 'Hello,\nWorld!',
    color: '#ffffff',
    font: { fontSize: 18, fontWeight: 'bold' },
    height: Ti.SIZE_AUTO,
    width: Ti.SIZE_AUTO,
    top: 20,
    left: 25,
    right: 25
});
mainBubble.add(mainLabel);

mainBubble.addEventListener('click', function(e) {
    statusLabel.text = 'Main bubble clicked at: ' + e.x.toFixed(0) + ', ' + e.y.toFixed(0);
});

win.add(mainBubble);

// ========================================
// Section 2: Control Panel
// ========================================
const section2Label = Ti.UI.createLabel({
    text: 'Controls',
    color: '#2c3e50',
    font: { fontSize: 16, fontWeight: 'bold' },
    top: 225,
    left: 10
});
win.add(section2Label);

// Row 1: Beak position buttons
const btnBeakLeft = Ti.UI.createButton({
    title: '◀ Left',
    top: 245,
    left: 20,
    width: 90,
});
btnBeakLeft.addEventListener('click', function() {
    mainBubble.bubbleBeak = tibubble.BUBBLE_BEAK_LEFT;
    statusLabel.text = 'Beak: Left';
});
win.add(btnBeakLeft);

const btnBeakRight = Ti.UI.createButton({
    title: 'Right ▶',
    top: 245,
    left: 120,
    width: 90,
});
btnBeakRight.addEventListener('click', function() {
    mainBubble.bubbleBeak = tibubble.BUBBLE_BEAK_RIGHT;
    statusLabel.text = 'Beak: Right';
});
win.add(btnBeakRight);

// Row 2: Vertical position buttons
const btnBeakLower = Ti.UI.createButton({
    title: '▼ Lower',
    top: 280,
    left: 20,
    width: 90,
});
btnBeakLower.addEventListener('click', function() {
    mainBubble.bubbleBeakVertical = tibubble.BUBBLE_BEAK_LOWER;
    statusLabel.text = 'Beak: Lower';
});
win.add(btnBeakLower);

const btnBeakUpper = Ti.UI.createButton({
    title: '▲ Upper',
    top: 280,
    left: 120,
    width: 90,
});
btnBeakUpper.addEventListener('click', function() {
    mainBubble.bubbleBeakVertical = tibubble.BUBBLE_BEAK_UPPER;
    statusLabel.text = 'Beak: Upper';
});
win.add(btnBeakUpper);

// Row 3: Color buttons
const btnRandomColor = Ti.UI.createButton({
    title: '🎨 Random',
    top: 315,
    left: 20,
    width: 90,
});
btnRandomColor.addEventListener('click', function() {
    const colors = ['#e74c3c', '#3498db', '#2ecc71', '#9b59b6', '#f39c12', '#1abc9c', '#e67e22', '#34495e'];
    const randomColor = colors[Math.floor(Math.random() * colors.length)];
    mainBubble.bubbleColor = randomColor;
    statusLabel.text = 'Color: ' + randomColor;
});
win.add(btnRandomColor);

const btnRedColor = Ti.UI.createButton({
    title: '🔴 Red',
    top: 315,
    left: 120,
    width: 90,
});
btnRedColor.addEventListener('click', function() {
    mainBubble.bubbleColor = '#e74c3c';
    statusLabel.text = 'Color: Red';
});
win.add(btnRedColor);

// Row 4: Radius control
let currentRadius = 25;
const btnRadiusPlus = Ti.UI.createButton({
    title: 'Radius +',
    top: 350,
    left: 20,
    width: 90,
});
btnRadiusPlus.addEventListener('click', function() {
    if (currentRadius < 50) {
        currentRadius += 5;
        mainBubble.bubbleRadius = currentRadius;
        statusLabel.text = 'Radius: ' + currentRadius;
    }
});
win.add(btnRadiusPlus);

const btnRadiusMinus = Ti.UI.createButton({
    title: 'Radius -',
    top: 350,
    left: 120,
    width: 90,
});
btnRadiusMinus.addEventListener('click', function() {
    if (currentRadius > 10) {
        currentRadius -= 5;
        mainBubble.bubbleRadius = currentRadius;
        statusLabel.text = 'Radius: ' + currentRadius;
    }
});
win.add(btnRadiusMinus);

// Row 5: Animation button
const btnAnimate = Ti.UI.createButton({
    title: '🎬 Animate',
    top: 385,
    left: 20,
    width: 190,
});
btnAnimate.addEventListener('click', function() {
    const newX = mainBubble.left === 20 ? 150 : 20;
    mainBubble.animate({
        duration: 500,
        left: newX,
        top: mainBubble.top === 95 ? 150 : 95,
        callback: function() {
            statusLabel.text = 'Animation complete! Position: ' + mainBubble.left + ', ' + mainBubble.top;
        }
    });
});
win.add(btnAnimate);

// ========================================
// Section 3: Bubble Variations
// ========================================
const section3Label = Ti.UI.createLabel({
    text: 'Variations',
    color: '#2c3e50',
    font: { fontSize: 16, fontWeight: 'bold' },
    top: 430,
    left: 10
});
win.add(section3Label);

// Small bubble
const smallBubble = tibubble.createBubble({
    bubbleColor: '#2ecc71',
    bubbleRadius: 15,
    bubbleBeak: tibubble.BUBBLE_BEAK_RIGHT,
    bubbleBeakVertical: tibubble.BUBBLE_BEAK_LOWER,
    width: 100,
    height: 70,
    top: 450,
    left: 20
});
const smallLabel = Ti.UI.createLabel({
    text: 'Small',
    color: '#ffffff',
    font: { fontSize: 12, fontWeight: 'bold' },
    height: Ti.SIZE_AUTO,
    width: Ti.SIZE_AUTO,
    top: 10,
    left: 10
});
smallBubble.add(smallLabel);
win.add(smallBubble);

// Tall bubble
const tallBubble = tibubble.createBubble({
    bubbleColor: '#9b59b6',
    bubbleRadius: 30,
    bubbleBeak: tibubble.BUBBLE_BEAK_LEFT,
    bubbleBeakVertical: tibubble.BUBBLE_BEAK_UPPER,
    width: 100,
    height: 120,
    top: 450,
    left: 130
});
const tallLabel = Ti.UI.createLabel({
    text: 'Tall',
    color: '#ffffff',
    font: { fontSize: 12, fontWeight: 'bold' },
    height: Ti.SIZE_AUTO,
    width: Ti.SIZE_AUTO,
    top: 10,
    left: 10
});
tallBubble.add(tallLabel);
win.add(tallBubble);

// Wide bubble
const wideBubble = tibubble.createBubble({
    bubbleColor: '#e67e22',
    bubbleRadius: 20,
    bubbleBeak: tibubble.BUBBLE_BEAK_RIGHT,
    bubbleBeakVertical: tibubble.BUBBLE_BEAK_UPPER,
    width: 150,
    height: 60,
    top: 580,
    left: 20
});
const wideLabel = Ti.UI.createLabel({
    text: 'Wide Bubble',
    color: '#ffffff',
    font: { fontSize: 12, fontWeight: 'bold' },
    height: Ti.SIZE_AUTO,
    width: Ti.SIZE_AUTO,
    top: 10,
    left: 10
});
wideBubble.add(wideLabel);
win.add(wideBubble);

// ========================================
// Section 4: Info Panel
// ========================================
const infoView = Ti.UI.createView({
    backgroundColor: '#ffffff',
    borderRadius: 10,
    top: 650,
    left: 10,
    right: 10,
    height: 150
});

const infoLabel = Ti.UI.createLabel({
    text: 'Module: de.marcbender.bubbleview\n' +
           'Version: 1.0.0\n' +
           'Author: Marc Bender',
    color: '#34495e',
    font: { fontSize: 12 },
    height: Ti.SIZE_AUTO,
    width: Ti.UI.SIZE,
    top: 10,
    left: 10
});
infoView.add(infoLabel);
win.add(infoView);

// Open window
win.open();