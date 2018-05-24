//
//  ViewController.m
//  arkit-by-example
//
//  Created by md on 6/8/17.
//  Copyright © 2017 ruanestudios. All rights reserved.
//

#import "ViewController.h"

@interface ViewController () <ARSCNViewDelegate, UIGestureRecognizerDelegate, SCNPhysicsContactDelegate>

@property (nonatomic, strong) IBOutlet ARSCNView *sceneView;

@end

@implementation ViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  [self setupScene];
  [self setupRecognizers];
}


- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [self setupSession];
}


- (void)viewWillDisappear:(BOOL)animated
{
  [super viewWillDisappear:animated];
    
  // Pause the view's session
  [self.sceneView.session pause];
}


- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Release any cached data, images, etc that aren't in use.
}


- (void)setupScene
{
  // Setup the ARSCNViewDelegate - this gives us callbacks to handle new
  // geometry creation
  self.sceneView.delegate = self;
  
  // A dictionary of all the current planes being rendered in the scene
  self.planes = [NSMutableDictionary new];
  
  // Contains a list of all the boxes rendered in the scene
  self.geometry = [NSMutableArray new];
  
  // Show statistics such as fps and timing information
  self.sceneView.showsStatistics = YES;
  self.sceneView.autoenablesDefaultLighting = YES;
  
  // Turn on debug options to show the world origin and also render all
  // of the feature points ARKit is tracking
  self.sceneView.debugOptions =
  ARSCNDebugOptionShowWorldOrigin |
  ARSCNDebugOptionShowFeaturePoints;
  
  // Add this to see bounding geometry for physics interactions
  //SCNDebugOptionShowPhysicsShapes;
  
  SCNScene *scene = [SCNScene new];
  self.sceneView.scene = scene;
}


- (void)setupSession
{
  // Create a session configuration
  ARWorldTrackingConfiguration *configuration = [ARWorldTrackingConfiguration new];
  
  // Specify that we do want to track horizontal planes. Setting this will cause the ARSCNViewDelegate
  // methods to be called when scenes are detected
  configuration.planeDetection = ARPlaneDetectionHorizontal;
  
  // Run the view's session
  [self.sceneView.session runWithConfiguration:configuration];
}


- (void)setupRecognizers
{
  // Single tap will insert a new piece of geometry into the scene
  UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapFrom:)];
  tapGestureRecognizer.numberOfTapsRequired = 1;
  [self.sceneView addGestureRecognizer:tapGestureRecognizer];
}


- (void)handleTapFrom: (UITapGestureRecognizer *)recognizer
{
  // Take the screen space tap coordinates and pass them to the hitTest method on the ARSCNView instance
  CGPoint tapPoint = [recognizer locationInView:self.sceneView];
  NSArray<ARHitTestResult *> *result = [self.sceneView hitTest:tapPoint types:ARHitTestResultTypeExistingPlaneUsingExtent];
  
  // If the intersection ray passes through any plane geometry they will be returned, with the planes
  // ordered by distance from the camera
  if (result.count == 0) {
    return;
  }
  
  // If there are multiple hits, just pick the closest plane
  ARHitTestResult * hitResult = [result firstObject];
  [self insertGeometry:hitResult];
}


- (void)insertGeometry:(ARHitTestResult *)hitResult
{
  // Right now we just insert a simple cube, later we will improve these to be more
  // interesting and have better texture and shading
  
  float dimension = 0.1;
  SCNBox *cube = [SCNBox boxWithWidth:dimension height:dimension length:dimension chamferRadius:0];
  SCNNode *node = [SCNNode nodeWithGeometry:cube];
  
  // The physicsBody tells SceneKit this geometry should be manipulated by the physics engine
  node.physicsBody = [SCNPhysicsBody bodyWithType:SCNPhysicsBodyTypeDynamic shape:nil];
  node.physicsBody.mass = 2.0;
  node.physicsBody.categoryBitMask = SCNPhysicsBodyTypeDynamic;
  
  // We insert the geometry slightly above the point the user tapped, so that it drops onto the plane
  // using the physics engine
  float insertionYOffset = 0.5;
  node.position = SCNVector3Make(
                                 hitResult.worldTransform.columns[3].x,
                                 hitResult.worldTransform.columns[3].y + insertionYOffset,
                                 hitResult.worldTransform.columns[3].z
                                 );
  [self.sceneView.scene.rootNode addChildNode:node];
  [self.geometry addObject:node];
}


- (void)renderer:(id <SCNSceneRenderer>)renderer didAddNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor
{
  if (![anchor isKindOfClass:[ARPlaneAnchor class]])
  {
    return;
  }
  
  // When a new plane is detected we create a new SceneKit plane to visualize it in 3D
  Plane *plane = [[Plane alloc] initWithAnchor: (ARPlaneAnchor *)anchor isHidden: NO];
  [self.planes setObject:plane forKey:anchor.identifier];
  [node addChildNode:plane];
}


/**
 Called when a node has been updated with data from the given anchor.
 
 @param renderer The renderer that will render the scene.
 @param node The node that was updated.
 @param anchor The anchor that was updated.
 */
- (void)renderer:(id <SCNSceneRenderer>)renderer didUpdateNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor
{
  Plane *plane = [self.planes objectForKey:anchor.identifier];
  if (plane == nil)
  {
    return;
  }
  
  // When an anchor is updated we need to also update our 3D geometry too. For example
  // the width and height of the plane detection may have changed so we need to update
  // our SceneKit geometry to match that
  [plane update:(ARPlaneAnchor *)anchor];
}


/**
 Called when a mapped node has been removed from the scene graph for the given anchor.
 
 @param renderer The renderer that will render the scene.
 @param node The node that was removed.
 @param anchor The anchor that was removed.
 */
/*
- (void)renderer:(id <SCNSceneRenderer>)renderer didRemoveNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor
{
  // Nodes will be removed if planes multiple individual planes that are detected to all be
  // part of a larger plane are merged.
  [self.planes removeObjectForKey:anchor.identifier];
}
 */

/**
 Called when a node will be updated with data from the given anchor.
 
 @param renderer The renderer that will render the scene.
 @param node The node that will be updated.
 @param anchor The anchor that was updated.
 */
- (void)renderer:(id <SCNSceneRenderer>)renderer willUpdateNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor{
}


- (void)session:(ARSession *)session didFailWithError:(NSError *)error {
  // Present an error message to the user
}


- (void)sessionWasInterrupted:(ARSession *)session
{
  // Inform the user that the session has been interrupted, for example, by presenting an overlay
}


- (void)sessionInterruptionEnded:(ARSession *)session
{
  // Reset tracking and/or remove existing anchors if consistent tracking is required
}

@end
